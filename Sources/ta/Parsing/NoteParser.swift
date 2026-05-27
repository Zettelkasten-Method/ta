// Sources/ta/Parsing/NoteParser.swift
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
        let stem = (filename as NSString).deletingPathExtension
        let ids = index.idPattern.extractIDs(from: stem)
        guard let primaryID = ids.first else {
            throw Error.missingTimestampPrefix(filename)
        }

        let title = Self.titleFromFilename(stem, id: primaryID)

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
            timestampID: primaryID,
            outgoingLinks: resolved,
            unresolvedLinkText: unresolved,
            tags: tags,
            nonCodeText: nonCodeText,
            rawText: source
        )
    }

    private static func titleFromFilename(_ stem: String, id: String) -> String {
        var result = stem
        if let range = result.range(of: id) {
            result.removeSubrange(range)
        }
        let separators: CharacterSet = .init(charactersIn: " -_")
        while let first = result.unicodeScalars.first, separators.contains(first) {
            result.removeFirst()
        }
        while let last = result.unicodeScalars.last, separators.contains(last) {
            result.removeLast()
        }
        return result.isEmpty ? stem : result
    }
}
