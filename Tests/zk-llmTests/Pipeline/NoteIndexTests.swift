// Tests/zk-llmTests/Pipeline/NoteIndexTests.swift
import Testing
import Foundation
@testable import zk_llm

@Suite("NoteIndex")
struct NoteIndexTests {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "sample-archive", withExtension: nil, subdirectory: "Fixtures")!
    }

    @Test("enumerate skips non-timestamp filenames")
    func enumerate() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        // Unknown Id Note.md has no prefix; must not be indexed.
        #expect(index.resolve(wikilinkText: "Unknown") == nil)
    }

    @Test("exact 12-digit match resolves")
    func exactMatch() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let ref = index.resolve(wikilinkText: "202503091430")
        #expect(ref?.filename == "202503091430 Mental Models.md")
    }

    @Test("unambiguous prefix match resolves (synthetic archive)")
    func prefixMatchSynthetic() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("zk-llm-idx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "".write(to: tmp.appendingPathComponent("111111111111 a.md"), atomically: true, encoding: .utf8)
        try "".write(to: tmp.appendingPathComponent("222222222222 b.md"), atomically: true, encoding: .utf8)
        let index = try NoteIndex(archiveDirectory: tmp)
        let ref = index.resolve(wikilinkText: "1111")
        #expect(ref?.filename == "111111111111 a.md")
    }

    @Test("ambiguous prefix returns nil")
    func ambiguousPrefix() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        // "20250309143" is a prefix of all notes in fixture — ambiguous.
        let ref = index.resolve(wikilinkText: "20250309143")
        #expect(ref == nil)
    }

    @Test("missing ID returns nil")
    func missing() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let ref = index.resolve(wikilinkText: "999999999999")
        #expect(ref == nil)
    }

    @Test("count of indexed notes matches fixture")
    func count() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        // 12 of 13 fixture files have 12-digit prefixes; Unknown Id Note.md is excluded.
        #expect(index.count == 12)
    }
}
