import AppKit
import Foundation

/// Persists the user-selected break wallpaper as a real file under Application Support.
/// More reliable than security-scoped bookmarks for a non-sandboxed menu bar app.
enum WallpaperStore {
    private static let folderName = "com.takeabreak.app/Wallpapers"
    private static let filePrefix = "custom_wallpaper"

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Copies `source` into Application Support and returns the destination URL.
    @discardableResult
    static func saveCustom(from source: URL) throws -> URL {
        let scoped = source.startAccessingSecurityScopedResource()
        defer {
            if scoped { source.stopAccessingSecurityScopedResource() }
        }

        // Ensure we can read the source (fileImporter grants temporary access).
        guard FileManager.default.isReadableFile(atPath: source.path) else {
            throw WallpaperError.unreadableSource
        }

        // Prefer decoding via NSImage so HEIC/etc. become a portable PNG.
        guard let image = NSImage(contentsOf: source) else {
            throw WallpaperError.decodeFailed
        }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw WallpaperError.encodeFailed
        }

        clearCustomFiles()
        let dest = directory.appendingPathComponent("\(filePrefix).png")
        try png.write(to: dest, options: .atomic)
        return dest
    }

    static func customImageURL() -> URL? {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.first { $0.lastPathComponent.hasPrefix(filePrefix) }
    }

    static func loadCustomImage() -> NSImage? {
        guard let url = customImageURL() else { return nil }
        return NSImage(contentsOf: url)
    }

    static func hasCustomImage() -> Bool {
        customImageURL() != nil
    }

    static func clearCustomFiles() {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for url in contents where url.lastPathComponent.hasPrefix(filePrefix) {
            try? fm.removeItem(at: url)
        }
    }

    enum WallpaperError: LocalizedError {
        case unreadableSource
        case decodeFailed
        case encodeFailed

        var errorDescription: String? {
            switch self {
            case .unreadableSource: return "无法读取所选文件"
            case .decodeFailed: return "无法识别该图片格式"
            case .encodeFailed: return "保存壁纸失败"
            }
        }
    }
}
