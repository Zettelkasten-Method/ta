// Sources/zk-llm/Model/NoteRef.swift
import Foundation

public struct NoteRef: Hashable, Sendable {
    public let filename: String

    public init(filename: String) {
        self.filename = filename
    }
}
