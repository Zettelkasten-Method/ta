import Foundation
@testable import TACore

func makeFixtureConfig(_ url: URL) -> ResolvedConfig {
    ResolvedConfig(
        archiveDirectory: url,
        archiveSource: .flag,
        idPattern: .default,
        idPatternSource: .builtInDefault
    )
}
