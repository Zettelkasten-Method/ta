// Tests/taTests/Pipeline/StructuralFilterTests.swift
import Testing
import Foundation
@testable import TACore

@Suite("StructuralFilter")
struct StructuralFilterTests {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "sample-archive", withExtension: nil, subdirectory: "Fixtures")!
    }

    @Test("tag predicate rejects candidate where #tag only appears in code")
    func rejectsCodeOnlyTag() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let filter = StructuralFilter(index: index, archiveDirectory: fixtureURL())
        let candidate = NoteRef(filename: "202503091436 Coding Note.md")
        // This candidate contains #fake-tag inside a code fence only.
        let hits = try filter.verify(
            candidates: [candidate],
            predicates: [.tag("fake-tag")]
        )
        #expect(hits.isEmpty)
    }

    @Test("tag predicate accepts candidate with real tag")
    func acceptsRealTag() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let filter = StructuralFilter(index: index, archiveDirectory: fixtureURL())
        let candidate = NoteRef(filename: "202503091436 Coding Note.md")
        let hits = try filter.verify(
            candidates: [candidate],
            predicates: [.tag("code")]
        )
        #expect(hits.count == 1)
        #expect(hits[0].note.ref == candidate)
        #expect(hits[0].depth == 0)
        #expect(hits[0].via == nil)
        #expect(hits[0].snippet?.isEmpty == false)
    }

    @Test("phrase predicate")
    func phrase() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let filter = StructuralFilter(index: index, archiveDirectory: fixtureURL())
        let candidate = NoteRef(filename: "202503091430 Mental Models.md")
        let hits = try filter.verify(
            candidates: [candidate],
            predicates: [.phrase("Second-order")]
        )
        #expect(hits.count == 1)
        #expect(hits[0].snippet?.contains("Second-order") == true)
    }

    @Test("phrase predicate matches text inside inline code")
    func phraseInsideInlineCode() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-sf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let url = tmp.appendingPathComponent("111111111111 inline code note.md")
        try "A `LSUIElement` aka menu bar extra is a thing.".write(to: url, atomically: true, encoding: .utf8)
        let index = try NoteIndex(archiveDirectory: tmp)
        let filter = StructuralFilter(index: index, archiveDirectory: tmp)
        let hits = try filter.verify(
            candidates: [NoteRef(filename: url.lastPathComponent)],
            predicates: [.phrase("LSUIElement")]
        )
        #expect(hits.count == 1)
        #expect(hits[0].snippet?.contains("LSUIElement") == true)
    }

    @Test("word predicate matches text inside inline code")
    func wordInsideInlineCode() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-sf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let url = tmp.appendingPathComponent("111111111111 inline code word.md")
        try "Launching from a `LSUIElement` status bar app works.".write(to: url, atomically: true, encoding: .utf8)
        let index = try NoteIndex(archiveDirectory: tmp)
        let filter = StructuralFilter(index: index, archiveDirectory: tmp)
        let hits = try filter.verify(
            candidates: [NoteRef(filename: url.lastPathComponent)],
            predicates: [.word("LSUIElement")]
        )
        #expect(hits.count == 1)
        #expect(hits[0].snippet?.contains("LSUIElement") == true)
    }

    @Test("phrase, word, and tag predicates are case-insensitive")
    func caseInsensitive() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-sf-ci-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let url = tmp.appendingPathComponent("111111111111 case note.md")
        try "A `LSUIElement` line and #MacOS tag.".write(to: url, atomically: true, encoding: .utf8)
        let index = try NoteIndex(archiveDirectory: tmp)
        let filter = StructuralFilter(index: index, archiveDirectory: tmp)
        let candidate = NoteRef(filename: url.lastPathComponent)

        let phraseHits = try filter.verify(candidates: [candidate], predicates: [.phrase("lsuielement")])
        #expect(phraseHits.count == 1)

        let wordHits = try filter.verify(candidates: [candidate], predicates: [.word("LSUIELEMENT")])
        #expect(wordHits.count == 1)

        let tagHits = try filter.verify(candidates: [candidate], predicates: [.tag("macos")])
        #expect(tagHits.count == 1)
    }

    @Test("snippet window is measured in characters and clamped at both ends of a long text")
    func snippetClampsAtTextEdges() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-sf-snip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let nearStart = tmp.appendingPathComponent("111111111111 near start.md")
        try ("a👍🏽 needle then " + String(repeating: "filler ", count: 50))
            .write(to: nearStart, atomically: true, encoding: .utf8)
        let nearEnd = tmp.appendingPathComponent("222222222222 near end.md")
        try (String(repeating: "abcde ", count: 50) + "0123456789 tail")
            .write(to: nearEnd, atomically: true, encoding: .utf8)
        let index = try NoteIndex(archiveDirectory: tmp)
        let filter = StructuralFilter(index: index, archiveDirectory: tmp, snippetWindow: 10)

        let startHits = try filter.verify(
            candidates: [NoteRef(filename: nearStart.lastPathComponent)],
            predicates: [.phrase("needle")]
        )
        #expect(startHits.map(\.snippet) == ["a👍🏽 needle"])

        let endHits = try filter.verify(
            candidates: [NoteRef(filename: nearEnd.lastPathComponent)],
            predicates: [.phrase("tail")]
        )
        #expect(endHits.map(\.snippet) == ["6789 tail"])
    }

    @Test("verbose logger captures verification summary")
    func verboseLogging() throws {
        let log = LogCapture()
        let logger = log.logger()
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let filter = StructuralFilter(index: index, archiveDirectory: fixtureURL(), logger: logger)
        _ = try filter.verify(
            candidates: [NoteRef(filename: "202503091430 Mental Models.md")],
            predicates: [.tag("learning")]
        )
        #expect(log.messages.contains { $0.contains("verify:") || $0.contains("filter:") })
    }

    @Test("multiple predicates all must match")
    func allMatch() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let filter = StructuralFilter(index: index, archiveDirectory: fixtureURL())
        let candidate = NoteRef(filename: "202503091430 Mental Models.md")
        // Has #learning but not #nonexistent.
        let hits = try filter.verify(
            candidates: [candidate],
            predicates: [.tag("learning"), .tag("nonexistent")]
        )
        #expect(hits.isEmpty)
    }
}
