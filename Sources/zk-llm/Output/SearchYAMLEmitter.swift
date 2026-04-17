import Foundation

public enum SearchYAMLEmitter {
    public static func emit(_ hits: [SearchHit]) -> String {
        guard !hits.isEmpty else { return "[]\n" }
        var out = ""
        for hit in hits {
            out += "- ref: \(yamlString(hit.note.ref.filename))\n"
            out += "  title: \(yamlString(hit.note.title))\n"
            if let snippet = hit.snippet, !snippet.isEmpty {
                out += "  snippet: \(yamlString(snippet))\n"
            }
            out += "  tags: \(yamlFlowList(hit.note.tags, quoted: false))\n"
            let links = hit.note.outgoingLinks.map(\.filename)
            out += "  links: \(yamlFlowList(links, quoted: true))\n"
            out += "  depth: \(hit.depth)\n"
            if let via = hit.via {
                out += "  via: \(yamlString(via.filename))\n"
            } else {
                out += "  via: null\n"
            }
        }
        return out
    }

    private static func yamlString(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                       .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func yamlFlowList(_ items: [String], quoted: Bool) -> String {
        if items.isEmpty { return "[]" }
        let rendered = items.map { quoted ? yamlString($0) : $0 }
        return "[" + rendered.joined(separator: ", ") + "]"
    }
}
