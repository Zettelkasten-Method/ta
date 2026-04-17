// Sources/zk-llm/Model/ParsedNote.swift
import Foundation

public struct ParsedNote: Sendable, Equatable {
    public let ref: NoteRef
    public let title: String
    public let timestampID: String
    public let outgoingLinks: [NoteRef]
    public let unresolvedLinkText: [String]
    public let tags: [String]
    public let nonCodeText: String

    public init(
        ref: NoteRef,
        title: String,
        timestampID: String,
        outgoingLinks: [NoteRef],
        unresolvedLinkText: [String],
        tags: [String],
        nonCodeText: String
    ) {
        self.ref = ref
        self.title = title
        self.timestampID = timestampID
        self.outgoingLinks = outgoingLinks
        self.unresolvedLinkText = unresolvedLinkText
        self.tags = tags
        self.nonCodeText = nonCodeText
    }
}
