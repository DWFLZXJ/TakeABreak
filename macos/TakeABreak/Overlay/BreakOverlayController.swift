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
        quote: QuoteItem,
        remainingMs: Int,
        progress: Double,
        allowSkip: Bool,
        wallpaperImage: NSImage?
    ) {
        hide()

        for screen in NSScreen.screens {
            let view = BreakOverlayView(
                message: message,
                quote: quote,
                remainingMs: remainingMs,
                progress: progress,
                allowSkip: allowSkip,
                wallpaperImage: wallpaperImage,
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
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
            hosts.append(hosting)
        }
    }

    func update(message: String, remainingMs: Int, progress: Double) {
        for hosting in hosts {
            let current = hosting.rootView
            hosting.rootView = BreakOverlayView(
                message: message,
                quote: current.quote,
                remainingMs: remainingMs,
                progress: progress,
                allowSkip: current.allowSkip,
                wallpaperImage: current.wallpaperImage,
                onSkip: current.onSkip
            )
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
}
