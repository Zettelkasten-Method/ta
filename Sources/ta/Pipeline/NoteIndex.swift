// Sources/ta/Pipeline/NoteIndex.swift
import Foundation

public struct NoteIndex: Sendable {
    public let archiveDirectory: URL
    private let byTimestampID: [String: [NoteRef]]
    private let sortedTimestampIDs: [String]

    public var count: Int { byTimestampID.values.reduce(0) { $0 + $1.count } }

    public init(archiveDirectory: URL) throws {
        self.archiveDirectory = archiveDirectory
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: archiveDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
        var map: [String: [NoteRef]] = [:]
        for url in contents where url.pathExtension == "md" {
            let filename = url.lastPathComponent
            guard let prefix = Self.extractTimestampPrefix(filename) else { continue }
            map[prefix, default: []].append(NoteRef(filename: filename))
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
