// Sources/zk-llm/Pipeline/StructuralFilter.swift
import Foundation

public struct StructuralFilter {
    public let index: NoteIndex
    public let archiveDirectory: URL
    public let snippetWindow: Int

    public init(index: NoteIndex, archiveDirectory: URL, snippetWindow: Int = 120) {
        self.index = index
        self.archiveDirectory = archiveDirectory
        self.snippetWindow = snippetWindow
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
                continue
            }
            guard let hitOffset = firstPassingOffset(note: note, predicates: predicates) else {
                continue
            }
            let snippet = Self.snippet(from: note.nonCodeText, around: hitOffset, window: snippetWindow)
            hits.append(SearchHit(note: note, depth: 0, via: nil, snippet: snippet))
        }
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
                guard note.tags.contains(tag) else { return nil }
                let needle = "#\(tag)"
                if let range = note.nonCodeText.range(of: needle) {
                    let offset = note.nonCodeText.distance(from: note.nonCodeText.startIndex, to: range.lowerBound)
                    firstHit = firstHit.map { min($0, offset) } ?? offset
                }
            case .phrase(let phrase):
                guard let range = note.nonCodeText.range(of: phrase) else { return nil }
                let offset = note.nonCodeText.distance(from: note.nonCodeText.startIndex, to: range.lowerBound)
                firstHit = firstHit.map { min($0, offset) } ?? offset
            case .word(let word):
                guard let range = Self.wordMatch(word: word, in: note.nonCodeText) else { return nil }
                let offset = note.nonCodeText.distance(from: note.nonCodeText.startIndex, to: range.lowerBound)
                firstHit = firstHit.map { min($0, offset) } ?? offset
            }
        }
        return firstHit ?? 0
    }

    private static func wordMatch(word: String, in text: String) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = "\\b\(escaped)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
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
