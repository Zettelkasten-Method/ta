// Sources/ta/Model/SearchHit.swift
import Foundation

public struct SearchHit: Sendable, Equatable {
    public let note: ParsedNote
    public let depth: Int
    public let via: NoteRef?
    public let snippet: String?

    public init(note: ParsedNote, depth: Int, via: NoteRef?, snippet: String?) {
        self.note = note
        self.depth = depth
        self.via = via
        self.snippet = snippet
    }
}
