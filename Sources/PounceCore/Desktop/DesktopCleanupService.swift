import Foundation

public struct DesktopCleanupCandidate: Identifiable, Equatable, Sendable {
    public let id: String
    public let url: URL
    public let name: String
    public let byteCount: Int64
    public let reason: String

    public init(url: URL, byteCount: Int64, reason: String) {
        self.id = url.path
        self.url = url
        self.name = url.lastPathComponent
        self.byteCount = byteCount
        self.reason = reason
    }
}

public protocol DesktopFileSystem {
    func contentsOfDirectory(at url: URL) throws -> [URL]
    func byteCount(for url: URL) throws -> Int64
    func isDirectory(_ url: URL) throws -> Bool
    func isSymbolicLink(_ url: URL) throws -> Bool
    func moveToTrash(_ url: URL) throws
}

public struct LocalDesktopFileSystem: DesktopFileSystem {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func contentsOfDirectory(at url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .volumeURLKey],
            options: [.skipsHiddenFiles]
        )
    }

    public func byteCount(for url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
        return Int64(values.totalFileSize ?? values.fileSize ?? 0)
    }

    public func isDirectory(_ url: URL) throws -> Bool {
        try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
    }

    public func isSymbolicLink(_ url: URL) throws -> Bool {
        try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink ?? false
    }

    public func moveToTrash(_ url: URL) throws {
        var trashedURL: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &trashedURL)
    }
}

public struct DesktopCleanupService {
    public let fileSystem: DesktopFileSystem

    public init(fileSystem: DesktopFileSystem = LocalDesktopFileSystem()) {
        self.fileSystem = fileSystem
    }

    public func preview(desktopURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")) -> Result<[DesktopCleanupCandidate], Error> {
        do {
            let candidates = try fileSystem.contentsOfDirectory(at: desktopURL).compactMap { url -> DesktopCleanupCandidate? in
                guard Self.isSafeCandidate(url, desktopURL: desktopURL, fileSystem: fileSystem) else { return nil }
                let size = (try? fileSystem.byteCount(for: url)) ?? 0
                return DesktopCleanupCandidate(url: url, byteCount: size, reason: Self.reason(for: url))
            }
            return .success(candidates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        } catch {
            return .failure(error)
        }
    }

    public func moveToTrash(_ candidates: [DesktopCleanupCandidate]) -> [Result<URL, Error>] {
        candidates.map { candidate in
            do {
                try fileSystem.moveToTrash(candidate.url)
                return .success(candidate.url)
            } catch {
                return .failure(error)
            }
        }
    }

    private static func isSafeCandidate(_ url: URL, desktopURL: URL, fileSystem: DesktopFileSystem) -> Bool {
        guard url.deletingLastPathComponent().standardizedFileURL.path == desktopURL.standardizedFileURL.path,
              !url.lastPathComponent.hasPrefix("."),
              url.pathExtension.lowercased() != "app" else {
            return false
        }
        do {
            let isSymbolicLink = try fileSystem.isSymbolicLink(url)
            let isDirectory = try fileSystem.isDirectory(url)
            if isSymbolicLink || isDirectory {
                return false
            }
        } catch {
            return false
        }
        return true
    }

    private static func reason(for url: URL) -> String {
        let lowercasedName = url.lastPathComponent.lowercased()
        if lowercasedName.hasPrefix("screenshot") || lowercasedName.contains("screen shot") {
            return "Screenshot candidate"
        }
        if ["dmg", "zip", "pdf"].contains(url.pathExtension.lowercased()) {
            return "Temporary download candidate"
        }
        return "Desktop file"
    }
}
