// Tests/taTests/Model/NoteRefTests.swift
import Testing
@testable import ta

@Suite("NoteRef")
struct NoteRefTests {
    @Test("equality by filename")
    func equality() {
        let a = NoteRef(filename: "202503091430 Title.md")
        let b = NoteRef(filename: "202503091430 Title.md")
        #expect(a == b)
    }

    @Test("inequality on different filenames")
    func inequality() {
        let a = NoteRef(filename: "202503091430 Title.md")
        let b = NoteRef(filename: "202503091431 Title.md")
        #expect(a != b)
    }

    @Test("hashable")
    func hashing() {
        let set: Set<NoteRef> = [
            NoteRef(filename: "a.md"),
            NoteRef(filename: "a.md"),
            NoteRef(filename: "b.md"),
        ]
        #expect(set.count == 2)
    }
}
