import Testing
import Foundation
@testable import ta

@Suite("SearchPipeline")
struct SearchCommandTests {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "sample-archive", withExtension: nil, subdirectory: "Fixtures")!
    }

    @Test("search by tag returns direct hits with snippet")
    func searchByTag() throws {
        let yaml = try SearchPipeline.run(
            archiveDirectory: fixtureURL(),
            predicates: [.tag("learning")],
            depth: 0
        )
        #expect(yaml.contains("ref: \"202503091430 Mental Models.md\""))
        #expect(yaml.contains("depth: 0"))
        #expect(yaml.contains("snippet:"))
    }

    @Test("search with depth 1 pulls neighbors without snippet")
    func searchDepthOne() throws {
        let yaml = try SearchPipeline.run(
            archiveDirectory: fixtureURL(),
            predicates: [.tag("learning")],
            depth: 1
        )
        #expect(yaml.contains("202503091431 Second Order Thinking.md"))
        #expect(yaml.contains("depth: 1"))
        #expect(yaml.contains("via: \"202503091430 Mental Models.md\""))
    }

    @Test("no predicates is an error")
    func noPredicates() {
        #expect(throws: SearchPipeline.Error.self) {
            _ = try SearchPipeline.run(
                archiveDirectory: fixtureURL(),
                predicates: [],
                depth: 0
            )
        }
    }
}
