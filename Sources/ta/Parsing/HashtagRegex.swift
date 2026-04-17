// Sources/ta/Parsing/HashtagRegex.swift
import Foundation

public enum HashtagRegex {
    private static let pattern = try! NSRegularExpression(
        pattern: #"(?<=^|[^\p{L}\p{N}_])#([\p{L}\p{N}_-]+)"#,
        options: []
    )

    public static func extract(from text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        let matches = pattern.matches(in: text, options: [], range: range)
        var seen = Set<String>()
        var out: [String] = []
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            guard let r = Range(match.range(at: 1), in: text) else { continue }
            let tag = String(text[r])
            if seen.insert(tag).inserted {
                out.append(tag)
            }
        }
        return out
    }
}
