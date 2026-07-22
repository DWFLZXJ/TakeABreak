import AppKit
import SwiftUI

/// Manages borderless, high-level windows covering each display during breaks.
@MainActor
final class BreakOverlayController {
    var onSkip: (() -> Void)?
    var onRequestStop: (() -> Void)?

    private var windows: [NSWindow] = []
    private var hosts: [NSHostingView<BreakOverlayView>] = []

    func show(
        message: String,
        remainingMs: Int,
        progress: Double,
        allowSkip: Bool,
        wallpaperId: String,
        wallpaperBookmark: Data?
    ) {
        hide()
        let image = loadWallpaper(bookmark: wallpaperBookmark, id: wallpaperId)

        for screen in NSScreen.screens {
            let view = BreakOverlayView(
                message: message,
                remainingMs: remainingMs,
                progress: progress,
                allowSkip: allowSkip,
                wallpaperId: wallpaperId,
                wallpaperImage: image,
                onSkip: { [weak self] in self?.onSkip?() }
            )
            let hosting = NSHostingView(rootView: view)
            hosting.frame = screen.frame

            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.contentView = hosting
            window.isOpaque = true
            window.backgroundColor = .black
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            // Cover menu bar / dock area for this screen
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
            hosts.append(hosting)
        }
    }

    func update(message: String, remainingMs: Int, progress: Double) {
        for (index, hosting) in hosts.enumerated() {
            let current = hosting.rootView
            hosting.rootView = BreakOverlayView(
                message: message,
                remainingMs: remainingMs,
                progress: progress,
                allowSkip: current.allowSkip,
                wallpaperId: current.wallpaperId,
                wallpaperImage: current.wallpaperImage,
                onSkip: current.onSkip
            )
            _ = index
        }
    }

    func hide() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        hosts.removeAll()
    }

    private func loadWallpaper(bookmark: Data?, id: String) -> NSImage? {
        guard id == "custom", let bookmark else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard url.startAccessingSecurityScopedResource() else { return nil }
            defer { url.stopAccessingSecurityScopedResource() }
            return NSImage(contentsOf: url)
        } catch {
            return nil
        }
    }
}
