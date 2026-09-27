import Foundation

public enum WikiLinkRegex {
    private static let pattern = try! NSRegularExpression(
        pattern: #"\[\[([^\]|\n]+)(?:\|[^\]\n]+)?\]\]"#,
        options: []
    )

    public static func extractTargets(from text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        let matches = pattern.matches(in: text, options: [], range: range)
        var seen = Set<String>()
        var out: [String] = []
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            guard let r = Range(match.range(at: 1), in: text) else { continue }
            let target = String(text[r])
            if seen.insert(target).inserted {
                out.append(target)
            }
        }
        return out
    }
}
