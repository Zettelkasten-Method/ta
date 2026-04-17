import Testing
import Foundation
@testable import zk_llm

@Suite("TagPipeline")
struct TagCommandTests {
    private func fixtureURL() -> URL {
        Bundle.module.url(forResource: "sample-archive", withExtension: nil, subdirectory: "Fixtures")!
    }

    @Test("tag command behaves like search --tag")
    func tagEqualsSearch() throws {
        let viaTag = try SearchPipeline.run(
            archiveDirectory: fixtureURL(),
            predicates: [.tag("thinking")],
            depth: 0
        )
        #expect(viaTag.contains("202503091430 Mental Models.md"))
        #expect(viaTag.contains("202503091431 Second Order Thinking.md"))
    }
}
