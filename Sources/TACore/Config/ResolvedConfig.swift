import Foundation

public struct ResolvedConfig: Sendable {
    enum ArchiveSource: Sendable, Equatable, CustomStringConvertible {
        case flag, environment, configFile

        var description: String {
            switch self {
            case .flag: "flag"
            case .environment: "env"
            case .configFile: "config"
            }
        }
    }

    enum IDPatternSource: Sendable, Equatable, CustomStringConvertible {
        case configFile, builtInDefault

        var description: String {
            switch self {
            case .configFile: "config"
            case .builtInDefault: "default"
            }
        }
    }

    let archiveDirectory: URL
    let archiveSource: ArchiveSource
    let idPattern: IDPattern
    let idPatternSource: IDPatternSource
}
