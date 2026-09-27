import Foundation

public struct ResolvedConfig: Sendable {
    public let archiveDirectory: URL
    public let archiveSource: String
    public let idPattern: IDPattern
    public let idPatternSource: String
}
