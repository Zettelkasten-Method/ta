import Foundation

public struct ShowEmitter {
    let index: NoteIndex
    let archiveDirectory: URL

    init(index: NoteIndex, archiveDirectory: URL) {
        self.index = index
        self.archiveDirectory = archiveDirectory
    }

    public struct EmitResult {
        public let output: String
        public let anyResolved: Bool
    }

    func emitWithStatus(refs: [NoteRef]) throws -> EmitResult {
        var out = ""
        var anyResolved = false
        for typedRef in refs {
            guard let ref = resolve(typedRef) else {
                out += errorBlock(ref: typedRef, label: "not-found")
                continue
            }
            let url = archiveDirectory.appending(path: ref.filename)
            let note: ParsedNote
            do {
                note = try NoteParser.parse(fileURL: url, index: index)
            } catch {
                out += errorBlock(ref: ref, label: "parse-failed")
                continue
            }
            out += "---\n"
            out += "ref: \(YAMLFragment.string(ref.filename))\n"
            out += "title: \(YAMLFragment.string(note.title))\n"
            out += "tags: \(YAMLFragment.flowList(note.tags, quoted: false))\n"
            out += "links: \(YAMLFragment.flowList(note.outgoingLinks.map(\.filename), quoted: true))\n"
            out += "---\n"
            let body = note.rawText
            out += body
            if !body.hasSuffix("\n") { out += "\n" }
            anyResolved = true
        }
        return EmitResult(output: out, anyResolved: anyResolved)
    }

    /// Falls back to the file system so an existing file the index skipped (no ID in its name) is not reported as not-found.
    private func resolve(_ typedRef: NoteRef) -> NoteRef? {
        if let indexed = index.canonicalRef(for: typedRef) { return indexed }
        let url = archiveDirectory.appending(path: typedRef.filename)
        return FileManager.default.fileExists(atPath: url.path) ? typedRef : nil
    }

    private func errorBlock(ref: NoteRef, label: String) -> String {
        "---\nref: \(YAMLFragment.string(ref.filename))\nerror: \(label)\n---\n"
    }

    func emit(refs: [NoteRef]) throws -> String {
        try emitWithStatus(refs: refs).output
    }
}
