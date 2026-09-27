import Foundation

struct ParsedNote: Sendable, Equatable {
    let ref: NoteRef
    let title: String
    let timestampID: String
    let outgoingLinks: [NoteRef]
    let tags: [String]
    let rawText: String
}
