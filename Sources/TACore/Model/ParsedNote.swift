// Sources/TACore/Model/ParsedNote.swift
import Foundation

struct ParsedNote: Sendable, Equatable {
    let ref: NoteRef
    let title: String
    let timestampID: String
    let outgoingLinks: [NoteRef]
    let unresolvedLinkText: [String]
    let tags: [String]
    let nonCodeText: String
    let rawText: String

    init(
        ref: NoteRef,
        title: String,
        timestampID: String,
        outgoingLinks: [NoteRef],
        unresolvedLinkText: [String],
        tags: [String],
        nonCodeText: String,
        rawText: String
    ) {
        self.ref = ref
        self.title = title
        self.timestampID = timestampID
        self.outgoingLinks = outgoingLinks
        self.unresolvedLinkText = unresolvedLinkText
        self.tags = tags
        self.nonCodeText = nonCodeText
        self.rawText = rawText
    }
}
