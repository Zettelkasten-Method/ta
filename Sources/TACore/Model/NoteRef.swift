// Sources/TACore/Model/NoteRef.swift
import Foundation

public struct NoteRef: Hashable, Sendable {
    let filename: String

    public init(filename: String) {
        self.filename = filename
    }
}
