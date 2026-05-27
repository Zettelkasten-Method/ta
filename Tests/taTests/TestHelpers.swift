import Foundation
@testable import ta

func makeFixtureConfig(_ url: URL) -> ResolvedConfig {
    ResolvedConfig(
        archiveDirectory: url,
        archiveSource: "test",
        idPattern: .default,
        idPatternSource: "default"
    )
}
