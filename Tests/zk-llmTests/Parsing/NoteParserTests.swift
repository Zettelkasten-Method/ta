// Tests/zk-llmTests/Parsing/NoteParserTests.swift
import Testing
import Foundation
@testable import zk_llm

@Suite("NoteParser")
struct NoteParserTests {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "sample-archive", withExtension: nil, subdirectory: "Fixtures")!
    }

    @Test("parses Mental Models with links, tags, and title")
    func mentalModels() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let url = fixtureURL().appendingPathComponent("202503091430 Mental Models.md")
        let note = try NoteParser.parse(fileURL: url, index: index)
        #expect(note.ref == NoteRef(filename: "202503091430 Mental Models.md"))
        #expect(note.title == "Mental Models")
        #expect(note.timestampID == "202503091430")
        #expect(note.tags == ["learning", "thinking"])
        #expect(note.outgoingLinks.contains(NoteRef(filename: "202503091431 Second Order Thinking.md")))
        #expect(note.outgoingLinks.contains(NoteRef(filename: "202503091432 Inversion.md")))
        #expect(note.outgoingLinks.contains(NoteRef(filename: "202503091433 Compounding.md")))
    }

    @Test("skips tags inside code blocks")
    func codeBlockSkipping() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let url = fixtureURL().appendingPathComponent("202503091436 Coding Note.md")
        let note = try NoteParser.parse(fileURL: url, index: index)
        #expect(note.tags == ["code"])
        #expect(!note.tags.contains("fake-tag"))
        #expect(!note.tags.contains("not-a-tag"))
    }

    @Test("URL fragments are not tags")
    func urlNote() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let url = fixtureURL().appendingPathComponent("202503091437 Url Note.md")
        let note = try NoteParser.parse(fileURL: url, index: index)
        #expect(note.tags == ["reference"])
    }

    @Test("unicode tags preserved")
    func unicodeTags() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let url = fixtureURL().appendingPathComponent("202503091438 Unicode Tag.md")
        let note = try NoteParser.parse(fileURL: url, index: index)
        #expect(note.tags == ["Ernährung", "日本語"])
    }

    @Test("unresolved wiki-link captured in unresolvedLinkText")
    func unresolved() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let url = fixtureURL().appendingPathComponent("202503091441 Unresolved Link.md")
        let note = try NoteParser.parse(fileURL: url, index: index)
        #expect(note.outgoingLinks.isEmpty)
        #expect(note.unresolvedLinkText == ["999999999999"])
    }
}
