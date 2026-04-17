// Tests/zk-llmTests/Commands/ShowCommandTests.swift
import Testing
import Foundation
@testable import zk_llm

@Suite("ShowPipeline")
struct ShowCommandTests {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "sample-archive", withExtension: nil, subdirectory: "Fixtures")!
    }

    @Test("single ref emits frontmatter and body")
    func singleRef() throws {
        let result = try ShowPipeline.run(
            archiveDirectory: fixtureURL(),
            refs: [NoteRef(filename: "202503091430 Mental Models.md")]
        )
        #expect(result.output.contains("# Mental Models"))
        #expect(result.output.contains("title: \"Mental Models\""))
        #expect(result.anyResolved == true)
    }

    @Test("unknown ref emits not-found, anyResolved=false")
    func unknown() throws {
        let result = try ShowPipeline.run(
            archiveDirectory: fixtureURL(),
            refs: [NoteRef(filename: "000000000000 Unknown.md")]
        )
        #expect(result.output.contains("error: not-found"))
        #expect(result.anyResolved == false)
    }

    @Test("mixed refs resolve partially, anyResolved=true")
    func mixed() throws {
        let result = try ShowPipeline.run(
            archiveDirectory: fixtureURL(),
            refs: [
                NoteRef(filename: "000000000000 Unknown.md"),
                NoteRef(filename: "202503091430 Mental Models.md"),
            ]
        )
        #expect(result.output.contains("error: not-found"))
        #expect(result.output.contains("# Mental Models"))
        #expect(result.anyResolved == true)
    }
}
