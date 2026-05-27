// Sources/ta/Pipeline/NoteIndex.swift
import Foundation

public struct NoteIndex: Sendable {
    public static let supportedExtensions: [String] = ["md", "txt"]

    public let archiveDirectory: URL
    public let idPattern: IDPattern
    private let byTimestampID: [String: [NoteRef]]
    private let sortedTimestampIDs: [String]

    public var count: Int { byTimestampID.values.reduce(0) { $0 + $1.count } }

    public init(archiveDirectory: URL, idPattern: IDPattern = .default, logger: Logger = .quiet) throws {
        self.archiveDirectory = archiveDirectory
        self.idPattern = idPattern
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: archiveDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
        var map: [String: [NoteRef]] = [:]
        let extensions = Set(Self.supportedExtensions)
        for url in contents where extensions.contains(url.pathExtension) {
            let filename = url.lastPathComponent
            let stem = (filename as NSString).deletingPathExtension
            let ids = idPattern.extractIDs(from: stem)
            if ids.isEmpty { continue }
            for id in ids {
                map[id, default: []].append(NoteRef(filename: filename))
            }
        }
        self.byTimestampID = map
        self.sortedTimestampIDs = map.keys.sorted()
    }

    public func resolve(wikilinkText: String) -> NoteRef? {
        let key = wikilinkText.trimmingCharacters(in: .whitespaces)
        if let candidates = byTimestampID[key], candidates.count == 1 {
            return candidates[0]
        }
        if key.count >= 1 {
            var unique: NoteRef?
            for id in sortedTimestampIDs where id.hasPrefix(key) {
                let refs = byTimestampID[id] ?? []
                for r in refs {
                    if unique == nil {
                        unique = r
                    } else if unique != r {
                        return nil
                    }
                }
            }
            return unique
        }
        return nil
    }

    public static func extractTimestampPrefix(_ filename: String) -> String? {
        guard filename.count >= 12 else { return nil }
        let first12 = filename.prefix(12)
        return first12.allSatisfy(\.isWholeNumber) ? String(first12) : nil
    }
}
