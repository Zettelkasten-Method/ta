// Tests/taTests/Pipeline/StructuralFilterTests.swift
import Testing
import Foundation
@testable import ta

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
