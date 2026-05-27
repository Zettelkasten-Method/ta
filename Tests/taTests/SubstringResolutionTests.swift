import Testing
import Foundation
@testable import ta

@Suite("Substring Resolution Integration")
struct SubstringResolutionTests {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "sample-archive", withExtension: nil, subdirectory: "Fixtures")!
    }

    @Test("filename substring wikilink resolves across suffix-timestamped notes")
    func filenameSubstringResolution() throws {
        let yaml = try SearchPipeline.run(
            config: makeFixtureConfig(fixtureURL()),
            predicates: [.phrase("links by title")],
            depth: 1
        )
        #expect(yaml.contains("Another Suffix Note 202506252103.md"))
        #expect(yaml.contains("Thinking About Thinking - Cognitive Distancing 202506252102.md"))
    }
}
