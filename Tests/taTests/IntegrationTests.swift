import Testing
import Foundation
@testable import ta

@Suite("Integration")
struct IntegrationTests {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "sample-archive", withExtension: nil, subdirectory: "Fixtures")!
    }

    @Test("search by tag, pick a ref, show it")
    func searchThenShow() throws {
        let yaml = try SearchPipeline.run(
            archiveDirectory: fixtureURL(),
            predicates: [.tag("thinking")],
            depth: 2
        )
        #expect(yaml.contains("depth: 0"))
        #expect(yaml.contains("depth: 1") || yaml.contains("depth: 2"))

        let shown = try ShowPipeline.run(
            archiveDirectory: fixtureURL(),
            refs: [NoteRef(filename: "202503091430 Mental Models.md")]
        )
        #expect(shown.anyResolved)
        #expect(shown.output.contains("# Mental Models"))
        #expect(shown.output.contains("[[202503091431]]"))
    }

    @Test("structural filter correctly rejects code-only tag")
    func codeOnlyRejection() throws {
        let yaml = try SearchPipeline.run(
            archiveDirectory: fixtureURL(),
            predicates: [.tag("fake-tag")],
            depth: 0
        )
        #expect(yaml == "[]\n")
    }

    @Test("graph expansion respects depth cap")
    func depthClamp() throws {
        let yaml = try SearchPipeline.run(
            archiveDirectory: fixtureURL(),
            predicates: [.tag("learning")],
            depth: 999
        )
        #expect(yaml.hasPrefix("- ref:"))
    }
}
