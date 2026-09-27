import Foundation

public struct ResolvedConfig: Sendable {
    let archiveDirectory: URL
    let archiveSource: String
    let idPattern: IDPattern
    let idPatternSource: String
}
