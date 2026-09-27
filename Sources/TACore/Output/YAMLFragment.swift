enum YAMLFragment {
    static func string(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                       .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    static func flowList(_ items: [String], quoted: Bool) -> String {
        if items.isEmpty { return "[]" }
        let rendered = items.map { quoted ? string($0) : $0 }
        return "[" + rendered.joined(separator: ", ") + "]"
    }
}
