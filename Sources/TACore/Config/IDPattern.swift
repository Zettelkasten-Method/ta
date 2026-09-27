import Foundation

public struct IDPattern: Sendable, Equatable {
    public let source: String
    private let regex: NSRegularExpression

    public static let `default` = IDPattern(rawSource: "\\d{12}")

    public init?(source: String) {
        guard let regex = try? NSRegularExpression(pattern: source) else { return nil }
        self.source = source
        self.regex = regex
    }

    private init(rawSource: String) {
        self.source = rawSource
        self.regex = try! NSRegularExpression(pattern: rawSource)
    }

    public func extractIDs(from filenameStem: String) -> [String] {
        let range = NSRange(filenameStem.startIndex..., in: filenameStem)
        let matches = regex.matches(in: filenameStem, range: range)
        var seen = Set<String>()
        var result: [String] = []
        for match in matches {
            if let r = Range(match.range, in: filenameStem) {
                let id = String(filenameStem[r])
                if seen.insert(id).inserted {
                    result.append(id)
                }
            }
        }
        return result
    }

    public static func == (lhs: IDPattern, rhs: IDPattern) -> Bool {
        lhs.source == rhs.source
    }
}
