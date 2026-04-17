// Sources/zk-llm/Output/ShowEmitter.swift
import Foundation

public struct ShowEmitter {
    public let index: NoteIndex
    public let archiveDirectory: URL

    public init(index: NoteIndex, archiveDirectory: URL) {
        self.index = index
        self.archiveDirectory = archiveDirectory
    }

    public struct EmitResult {
        public let output: String
        public let anyResolved: Bool
    }

    public func emitWithStatus(refs: [NoteRef]) throws -> EmitResult {
        var out = ""
        var anyResolved = false
        for ref in refs {
            let url = archiveDirectory.appendingPathComponent(ref.filename)
            let exists = FileManager.default.fileExists(atPath: url.path)
            if !exists {
                out += "---\n"
                out += "ref: \(yamlString(ref.filename))\n"
                out += "error: not-found\n"
                out += "---\n"
                continue
            }
            let note: ParsedNote
            do {
                note = try NoteParser.parse(fileURL: url, index: index)
            } catch {
                out += "---\n"
                out += "ref: \(yamlString(ref.filename))\n"
                out += "error: parse-failed\n"
                out += "---\n"
                continue
            }
            guard let body = try? String(contentsOf: url, encoding: .utf8) else {
                out += "---\n"
                out += "ref: \(yamlString(ref.filename))\n"
                out += "error: read-failed\n"
                out += "---\n"
                continue
            }
            out += "---\n"
            out += "ref: \(yamlString(ref.filename))\n"
            out += "title: \(yamlString(note.title))\n"
            out += "tags: \(yamlFlowList(note.tags, quoted: false))\n"
            out += "links: \(yamlFlowList(note.outgoingLinks.map(\.filename), quoted: true))\n"
            out += "---\n"
            out += body
            if !body.hasSuffix("\n") { out += "\n" }
            anyResolved = true
        }
        return EmitResult(output: out, anyResolved: anyResolved)
    }

    public func emit(refs: [NoteRef]) throws -> String {
        try emitWithStatus(refs: refs).output
    }

    private func yamlString(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                       .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func yamlFlowList(_ items: [String], quoted: Bool) -> String {
        if items.isEmpty { return "[]" }
        let rendered = items.map { quoted ? yamlString($0) : $0 }
        return "[" + rendered.joined(separator: ", ") + "]"
    }
}
