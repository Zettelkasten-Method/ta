// Tests/taTests/Pipeline/NoteIndexTests.swift
import Testing
import Foundation
@testable import ta

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
            .appendingPathComponent("ta-idx-\(UUID().uuidString)")
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
        // 12 prefix-timestamped + 2 suffix-timestamped = 14; Unknown Id Note.md is excluded.
        #expect(index.count == 14)
    }

    @Test("explicit default IDPattern produces same count as implicit")
    func explicitDefaultPattern() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL(), idPattern: .default)
        #expect(index.count == 14)
        #expect(index.resolve(wikilinkText: "202503091430")?.filename == "202503091430 Mental Models.md")
    }

    @Test("indexes suffix-timestamped filenames")
    func suffixTimestamp() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-idx-suffix-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "".write(to: tmp.appendingPathComponent("Thinking About Thinking 202506252102.md"), atomically: true, encoding: .utf8)
        let index = try NoteIndex(archiveDirectory: tmp)
        #expect(index.count == 1)
        #expect(index.resolve(wikilinkText: "202506252102")?.filename == "Thinking About Thinking 202506252102.md")
    }

    @Test("resolves by filename substring")
    func filenameSubstring() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let ref = index.resolve(wikilinkText: "Mental Models")
        #expect(ref?.filename == "202503091430 Mental Models.md")
    }

    @Test("filename substring resolution is case-insensitive")
    func filenameCaseInsensitive() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let ref = index.resolve(wikilinkText: "mental models")
        #expect(ref?.filename == "202503091430 Mental Models.md")
    }

    @Test("ambiguous filename substring returns nil")
    func ambiguousSubstring() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let ref = index.resolve(wikilinkText: "Ambiguous Prefix")
        #expect(ref == nil)
    }

    @Test("exact ID match takes priority over filename substring")
    func idPriorityOverSubstring() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let ref = index.resolve(wikilinkText: "202503091430")
        #expect(ref?.filename == "202503091430 Mental Models.md")
    }

    @Test("indexes .txt files alongside .md")
    func txtFilesIndexed() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-idx-txt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "".write(to: tmp.appendingPathComponent("111111111111 md note.md"), atomically: true, encoding: .utf8)
        try "".write(to: tmp.appendingPathComponent("222222222222 txt note.txt"), atomically: true, encoding: .utf8)
        try "".write(to: tmp.appendingPathComponent("333333333333 other.rtf"), atomically: true, encoding: .utf8)
        let index = try NoteIndex(archiveDirectory: tmp)
        #expect(index.count == 2)
        #expect(index.resolve(wikilinkText: "111111111111")?.filename == "111111111111 md note.md")
        #expect(index.resolve(wikilinkText: "222222222222")?.filename == "222222222222 txt note.txt")
        #expect(index.resolve(wikilinkText: "333333333333") == nil)
    }
}
