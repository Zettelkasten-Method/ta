// Tests/zk-llmTests/Output/ShowEmitterTests.swift
import Testing
import Foundation
@testable import zk_llm

@Suite("ShowEmitter")
struct ShowEmitterTests {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "sample-archive", withExtension: nil, subdirectory: "Fixtures")!
    }

    @Test("emits frontmatter and raw body for existing ref")
    func existing() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let emitter = ShowEmitter(index: index, archiveDirectory: fixtureURL())
        let out = try emitter.emit(refs: [NoteRef(filename: "202503091430 Mental Models.md")])
        #expect(out.hasPrefix("---\n"))
        #expect(out.contains("ref: \"202503091430 Mental Models.md\""))
        #expect(out.contains("title: \"Mental Models\""))
        #expect(out.contains("tags: [learning, thinking]"))
        #expect(out.contains("# Mental Models"))
        #expect(out.contains("Mental models are frameworks for thinking."))
    }

    @Test("emits error: not-found for missing ref")
    func missing() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let emitter = ShowEmitter(index: index, archiveDirectory: fixtureURL())
        let out = try emitter.emit(refs: [NoteRef(filename: "999999999999 Missing.md")])
        #expect(out.contains("ref: \"999999999999 Missing.md\""))
        #expect(out.contains("error: not-found"))
    }

    @Test("multiple refs are concatenated")
    func multiple() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let emitter = ShowEmitter(index: index, archiveDirectory: fixtureURL())
        let out = try emitter.emit(refs: [
            NoteRef(filename: "202503091430 Mental Models.md"),
            NoteRef(filename: "202503091431 Second Order Thinking.md"),
        ])
        #expect(out.contains("# Mental Models"))
        #expect(out.contains("# Second Order Thinking"))
        // Two frontmatter opening fences.
        let fenceCount = out.components(separatedBy: "\n---\nref:").count - 1
        let leadingOpenCount = out.hasPrefix("---\nref:") ? 1 : 0
        #expect(fenceCount + leadingOpenCount >= 2)
    }
}
