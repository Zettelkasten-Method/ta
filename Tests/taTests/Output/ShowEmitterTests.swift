// Tests/taTests/Output/ShowEmitterTests.swift
import Testing
import Foundation
@testable import TACore

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

    private func makeArchive(_ filenames: [String]) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-show-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        for name in filenames {
            try "# Body\n".write(to: tmp.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return tmp
    }

    private func refLineBytes(_ output: String) -> [UInt8]? {
        output.split(separator: "\n").first { $0.hasPrefix("ref: ") }.map { Array($0.utf8) }
    }

    @Test("plain-space ref resolves filename containing NBSP and prints on-disk name")
    func nbspFilename() throws {
        let onDisk = "201706290826 \u{00A7}\u{00A0}TextKit.txt"
        let archive = try makeArchive([onDisk])
        defer { try? FileManager.default.removeItem(at: archive) }
        let emitter = ShowEmitter(index: try NoteIndex(archiveDirectory: archive), archiveDirectory: archive)
        let result = try emitter.emitWithStatus(refs: [NoteRef(filename: "201706290826 \u{00A7} TextKit.txt")])
        #expect(result.anyResolved)
        #expect(refLineBytes(result.output) == Array("ref: \"\(onDisk)\"".utf8))
        #expect(result.output.contains("# Body"))
    }

    @Test("NFC-typed ref resolves NFD filename and prints on-disk name")
    func nfdFilename() throws {
        let onDisk = "202001010000 Sta\u{308}nder.md"
        let archive = try makeArchive([onDisk])
        defer { try? FileManager.default.removeItem(at: archive) }
        let emitter = ShowEmitter(index: try NoteIndex(archiveDirectory: archive), archiveDirectory: archive)
        let result = try emitter.emitWithStatus(refs: [NoteRef(filename: "202001010000 St\u{E4}nder.md")])
        #expect(result.anyResolved)
        #expect(refLineBytes(result.output) == Array("ref: \"\(onDisk)\"".utf8))
    }

    @Test("existing file without an ID reports parse-failed, not not-found")
    func unindexedFilename() throws {
        let archive = try makeArchive(["No ID here.md"])
        defer { try? FileManager.default.removeItem(at: archive) }
        let emitter = ShowEmitter(index: try NoteIndex(archiveDirectory: archive), archiveDirectory: archive)
        let result = try emitter.emitWithStatus(refs: [NoteRef(filename: "No ID here.md")])
        #expect(result.output == "---\nref: \"No ID here.md\"\nerror: parse-failed\n---\n")
    }
}
