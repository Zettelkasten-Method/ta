// Sources/ta/Pipeline/StructuralFilter.swift
import Foundation

public struct StructuralFilter {
    public let index: NoteIndex
    public let archiveDirectory: URL
    public let snippetWindow: Int
    public let logger: Logger

    public init(index: NoteIndex, archiveDirectory: URL, snippetWindow: Int = 120, logger: Logger = .quiet) {
        self.index = index
        self.archiveDirectory = archiveDirectory
        self.snippetWindow = snippetWindow
        self.logger = logger
    }

    public func verify(
        candidates: [NoteRef],
        predicates: [RipgrepRunner.Predicate]
    ) throws -> [SearchHit] {
        var hits: [SearchHit] = []
        for ref in candidates {
            let url = archiveDirectory.appendingPathComponent(ref.filename)
            let note: ParsedNote
            do {
                note = try NoteParser.parse(fileURL: url, index: index)
            } catch {
                logger.log("filter: skip \(ref.filename) (parse error)")
                continue
            }
            guard let hitOffset = firstPassingOffset(note: note, predicates: predicates) else {
                logger.log("filter: reject \(ref.filename) (predicates not satisfied)")
                continue
            }
            let snippet = Self.snippet(from: note.rawText, around: hitOffset, window: snippetWindow)
            hits.append(SearchHit(note: note, depth: 0, via: nil, snippet: snippet))
        }
        logger.log("filter: \(candidates.count) candidates in, \(hits.count) verified")
        return hits
    }

    private func firstPassingOffset(
        note: ParsedNote,
        predicates: [RipgrepRunner.Predicate]
    ) -> Int? {
        var firstHit: Int? = nil
        for predicate in predicates {
            switch predicate {
            case .tag(let tag):
                guard note.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) else { return nil }
                let needle = "#\(tag)"
                if let range = note.rawText.range(of: needle, options: .caseInsensitive) {
                    let offset = note.rawText.distance(from: note.rawText.startIndex, to: range.lowerBound)
                    firstHit = firstHit.map { min($0, offset) } ?? offset
                }
            case .phrase(let phrase):
                guard let range = note.rawText.range(of: phrase, options: .caseInsensitive) else { return nil }
                let offset = note.rawText.distance(from: note.rawText.startIndex, to: range.lowerBound)
                firstHit = firstHit.map { min($0, offset) } ?? offset
            case .word(let word):
                guard let range = Self.wordMatch(word: word, in: note.rawText) else { return nil }
                let offset = note.rawText.distance(from: note.rawText.startIndex, to: range.lowerBound)
                firstHit = firstHit.map { min($0, offset) } ?? offset
            }
        }
        return firstHit ?? 0
    }

    private static func wordMatch(word: String, in text: String) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = "\\b\(escaped)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else { return nil }
        return Range(match.range, in: text)
    }

    static func snippet(from text: String, around offset: Int, window: Int) -> String {
        let clampedOffset = max(0, min(offset, text.count))
        let start = max(0, clampedOffset - window / 2)
        let end = min(text.count, start + window)
        let startIdx = text.index(text.startIndex, offsetBy: start)
        let endIdx = text.index(text.startIndex, offsetBy: end)
        return String(text[startIdx..<endIdx])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }
}
