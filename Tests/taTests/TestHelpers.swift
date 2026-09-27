import Foundation
@testable import TACore

func makeFixtureConfig(_ url: URL) -> ResolvedConfig {
    ResolvedConfig(
        archiveDirectory: url,
        archiveSource: "test",
        idPattern: .default,
        idPatternSource: "default"
    )
}
