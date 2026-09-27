import Foundation

enum SearchYAMLEmitter {
    static func emit(_ hits: [SearchHit]) -> String {
        guard !hits.isEmpty else { return "[]\n" }
        var out = ""
        for hit in hits {
            out += "- ref: \(YAMLFragment.string(hit.note.ref.filename))\n"
            out += "  title: \(YAMLFragment.string(hit.note.title))\n"
            if let snippet = hit.snippet, !snippet.isEmpty {
                out += "  snippet: \(YAMLFragment.string(snippet))\n"
            }
            out += "  tags: \(YAMLFragment.flowList(hit.note.tags, quoted: false))\n"
            let links = hit.note.outgoingLinks.map(\.filename)
            out += "  links: \(YAMLFragment.flowList(links, quoted: true))\n"
            out += "  depth: \(hit.depth)\n"
            if let via = hit.via {
                out += "  via: \(YAMLFragment.string(via.filename))\n"
            } else {
                out += "  via: null\n"
            }
        }
        return out
    }
}
