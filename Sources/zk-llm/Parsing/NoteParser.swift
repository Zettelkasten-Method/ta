// Sources/zk-llm/Parsing/NoteParser.swift
import Foundation
import Markdown

public enum NoteParser {
    public enum Error: Swift.Error {
        case cannotReadFile(URL)
        case missingTimestampPrefix(String)
    }

    public static func parse(fileURL: URL, index: NoteIndex) throws -> ParsedNote {
        guard let data = try? Data(contentsOf: fileURL),
              let source = String(data: data, encoding: .utf8) else {
            throw Error.cannotReadFile(fileURL)
        }
        let filename = fileURL.lastPathComponent
        guard let prefix = NoteIndex.extractTimestampPrefix(filename) else {
            throw Error.missingTimestampPrefix(filename)
        }

        let title = Self.titleFromFilename(filename, prefix: prefix)

        let document = Document(parsing: source)
        let nonCodeText = NonCodeTextExtractor.extract(from: document)

        let tags = HashtagRegex.extract(from: nonCodeText)
        let linkTargets = WikiLinkRegex.extractTargets(from: nonCodeText)

        var resolved: [NoteRef] = []
        var unresolved: [String] = []
        for target in linkTargets {
            if let ref = index.resolve(wikilinkText: target) {
                if !resolved.contains(ref) {
                    resolved.append(ref)
                }
            } else {
                unresolved.append(target)
            }
        }

        return ParsedNote(
            ref: NoteRef(filename: filename),
            title: title,
            timestampID: prefix,
            outgoingLinks: resolved,
            unresolvedLinkText: unresolved,
            tags: tags,
            nonCodeText: nonCodeText
        )
    }

    private static func titleFromFilename(_ filename: String, prefix: String) -> String {
        var stem = filename
        if stem.hasSuffix(".md") { stem.removeLast(3) }
        guard stem.hasPrefix(prefix) else { return stem }
        stem.removeFirst(prefix.count)
        // Drop one leading separator character (space, dash, underscore).
        if let first = stem.first, first == " " || first == "-" || first == "_" {
            stem.removeFirst()
        }
        return stem
    }
}
