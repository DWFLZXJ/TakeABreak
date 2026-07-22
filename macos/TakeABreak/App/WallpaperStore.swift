import AppKit
import Foundation

/// Lists images in a user-chosen folder and picks one at random for each break.
enum WallpaperStore {
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tif", "tiff", "bmp"
    ]

    // MARK: - Folder resolution

    static func resolveFolder(path: String?, bookmark: Data?) -> URL? {
        if let bookmark, let url = resolveBookmark(bookmark) {
            return url
        }
        guard let path, !path.isEmpty else { return nil }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            return url
        }
        return try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    static func makeBookmark(for url: URL) -> Data? {
        if let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return data
        }
        return try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    // MARK: - Image listing

    /// Non-recursive listing of image files in `directory`.
    static func listImages(in directory: URL) -> [URL] {
        let scoped = directory.startAccessingSecurityScopedResource()
        defer {
            if scoped { directory.stopAccessingSecurityScopedResource() }
        }

        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return items.filter { url in
            let ext = url.pathExtension.lowercased()
            guard imageExtensions.contains(ext) else { return false }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return values?.isRegularFile == true
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func imageCount(path: String?, bookmark: Data?) -> Int {
        guard let folder = resolveFolder(path: path, bookmark: bookmark) else { return 0 }
        return listImages(in: folder).count
    }

    /// Random image from the configured folder; `nil` if missing/empty/unreadable.
    static func randomImage(path: String?, bookmark: Data?) -> NSImage? {
        guard let folder = resolveFolder(path: path, bookmark: bookmark) else { return nil }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer {
            if scoped { folder.stopAccessingSecurityScopedResource() }
        }
        let images = listImages(in: folder)
        guard let url = images.randomElement() else { return nil }
        return NSImage(contentsOf: url)
    }
}
