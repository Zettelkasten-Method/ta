// Sources/TACore/Model/SearchHit.swift
import Foundation

struct SearchHit: Sendable, Equatable {
    let note: ParsedNote
    let depth: Int
    let via: NoteRef?
    let snippet: String?

    init(note: ParsedNote, depth: Int, via: NoteRef?, snippet: String?) {
        self.note = note
        self.depth = depth
        self.via = via
        self.snippet = snippet
    }
}
