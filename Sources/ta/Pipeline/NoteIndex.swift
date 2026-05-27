// Sources/ta/Pipeline/NoteIndex.swift
import Foundation

public struct NoteIndex: Sendable {
    public static let supportedExtensions: [String] = ["md", "txt"]

    public let archiveDirectory: URL
    public let idPattern: IDPattern
    public let logger: Logger
    private let byTimestampID: [String: [NoteRef]]
    private let sortedTimestampIDs: [String]
    private let stemsByFilename: [String: String]

    public var count: Int { byTimestampID.values.reduce(0) { $0 + $1.count } }

    public init(archiveDirectory: URL, idPattern: IDPattern = .default, logger: Logger = .quiet) throws {
        self.archiveDirectory = archiveDirectory
        self.idPattern = idPattern
        self.logger = logger
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: archiveDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
        var map: [String: [NoteRef]] = [:]
        var stems: [String: String] = [:]
        let extensions = Set(Self.supportedExtensions)
        var totalFiles = 0
        var acceptedByExt = 0
        var skippedNoID = 0
        for url in contents {
            let filename = url.lastPathComponent
            guard extensions.contains(url.pathExtension) else {
                logger.log("skip (extension): \(filename)")
                continue
            }
            totalFiles += 1
            let stem = (filename as NSString).deletingPathExtension
            let ids = idPattern.extractIDs(from: stem)
            if ids.isEmpty {
                skippedNoID += 1
                logger.log("skip (no ID match): \(filename)")
                continue
            }
            acceptedByExt += 1
            stems[filename] = stem
            for id in ids {
                map[id, default: []].append(NoteRef(filename: filename))
            }
        }
        logger.log("index: \(totalFiles) files scanned, \(acceptedByExt) by extension, \(skippedNoID) no ID, \(map.count) unique IDs")
        self.byTimestampID = map
        self.sortedTimestampIDs = map.keys.sorted()
        self.stemsByFilename = stems
    }

    public func resolve(wikilinkText: String) -> NoteRef? {
        let key = wikilinkText.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }

        if let candidates = byTimestampID[key], candidates.count == 1 {
            let ref = candidates[0]
            logger.log("resolve [[\(key)]]: exact ID -> \(ref.filename)")
            return ref
        }

        if let match = resolveByFilenameSubstring(key) {
            logger.log("resolve [[\(key)]]: filename match -> \(match.filename)")
            return match
        }

        if let match = resolveByIDPrefix(key) {
            logger.log("resolve [[\(key)]]: prefix match -> \(match.filename)")
            return match
        }

        logger.log("resolve [[\(key)]]: unresolved")
        return nil
    }

    private func resolveByFilenameSubstring(_ key: String) -> NoteRef? {
        var unique: NoteRef?
        for (filename, stem) in stemsByFilename {
            if stem.range(of: key, options: .caseInsensitive) != nil {
                let ref = NoteRef(filename: filename)
                if unique == nil {
                    unique = ref
                } else if unique != ref {
                    return nil
                }
            }
        }
        return unique
    }

    private func resolveByIDPrefix(_ key: String) -> NoteRef? {
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

    public static func extractTimestampPrefix(_ filename: String) -> String? {
        guard filename.count >= 12 else { return nil }
        let first12 = filename.prefix(12)
        return first12.allSatisfy(\.isWholeNumber) ? String(first12) : nil
    }
}
