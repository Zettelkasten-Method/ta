// Tests/zk-llmTests/Pipeline/GraphExpanderTests.swift
import Testing
import Foundation
@testable import zk_llm

@Suite("GraphExpander")
struct GraphExpanderTests {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "sample-archive", withExtension: nil, subdirectory: "Fixtures")!
    }

    @Test("depth 0 returns only the direct hit")
    func depthZero() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let filter = StructuralFilter(index: index, archiveDirectory: fixtureURL())
        let direct = try filter.verify(
            candidates: [NoteRef(filename: "202503091430 Mental Models.md")],
            predicates: [.tag("learning")]
        )
        let expander = GraphExpander(index: index, archiveDirectory: fixtureURL())
        let all = try expander.expand(directHits: direct, depth: 0)
        #expect(all.count == 1)
        #expect(all[0].depth == 0)
    }

    @Test("depth 1 pulls in directly linked neighbors")
    func depthOne() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let filter = StructuralFilter(index: index, archiveDirectory: fixtureURL())
        let direct = try filter.verify(
            candidates: [NoteRef(filename: "202503091430 Mental Models.md")],
            predicates: [.tag("learning")]
        )
        let expander = GraphExpander(index: index, archiveDirectory: fixtureURL())
        let all = try expander.expand(directHits: direct, depth: 1)
        let refs = all.map(\.note.ref.filename)
        #expect(refs.contains("202503091431 Second Order Thinking.md"))
        #expect(refs.contains("202503091432 Inversion.md"))
        #expect(refs.contains("202503091433 Compounding.md"))
        // All non-hit nodes have depth 1 and via = Mental Models.
        for hit in all where hit.depth > 0 {
            #expect(hit.via == NoteRef(filename: "202503091430 Mental Models.md"))
            #expect(hit.depth == 1)
        }
    }

    @Test("depth 2 reaches one hop further, with correct via")
    func depthTwo() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let filter = StructuralFilter(index: index, archiveDirectory: fixtureURL())
        let direct = try filter.verify(
            candidates: [NoteRef(filename: "202503091430 Mental Models.md")],
            predicates: [.tag("learning")]
        )
        let expander = GraphExpander(index: index, archiveDirectory: fixtureURL())
        let all = try expander.expand(directHits: direct, depth: 2)
        // 202503091431 (Second Order) → 202503091433 (Compounding) — already reached at depth 1 via Mental Models.
        // 202503091433 (Compounding) → 202503091434 (Feedback Loops) — reached at depth 2 via Compounding.
        let feedback = all.first { $0.note.ref.filename == "202503091434 Feedback Loops.md" }
        #expect(feedback != nil)
        #expect(feedback?.depth == 2)
        #expect(feedback?.via == NoteRef(filename: "202503091433 Compounding.md"))
    }

    @Test("cycles are deduped")
    func cycles() throws {
        // Mental Models → Inversion → Mental Models creates a cycle.
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let filter = StructuralFilter(index: index, archiveDirectory: fixtureURL())
        let direct = try filter.verify(
            candidates: [NoteRef(filename: "202503091430 Mental Models.md")],
            predicates: [.tag("learning")]
        )
        let expander = GraphExpander(index: index, archiveDirectory: fixtureURL())
        let all = try expander.expand(directHits: direct, depth: 5)
        let refs = all.map(\.note.ref.filename)
        let mmCount = refs.filter { $0 == "202503091430 Mental Models.md" }.count
        #expect(mmCount == 1)
    }

    @Test("depth cap is clamped to 10")
    func depthClamp() throws {
        let index = try NoteIndex(archiveDirectory: fixtureURL())
        let filter = StructuralFilter(index: index, archiveDirectory: fixtureURL())
        let direct = try filter.verify(
            candidates: [NoteRef(filename: "202503091430 Mental Models.md")],
            predicates: [.tag("learning")]
        )
        let expander = GraphExpander(index: index, archiveDirectory: fixtureURL())
        let capped = try expander.expand(directHits: direct, depth: 999)
        let atMost10 = capped.allSatisfy { $0.depth <= 10 }
        #expect(atMost10)
    }
}
