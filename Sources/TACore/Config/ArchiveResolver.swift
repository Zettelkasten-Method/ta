import Foundation
import Yams

public struct ArchiveResolver {
    public enum Error: Swift.Error, CustomStringConvertible {
        case notConfigured(configPath: String)
        case notADirectory(String)

        public var description: String {
            switch self {
            case .notConfigured(let path):
                return """
                    No archive configured. Choose one (highest precedence first):
                      1. --archive /path/to/archive (flag on every invocation)
                      2. export TA_DIR=/path/to/archive
                      3. echo 'archive: /path/to/archive' > \(path)
                    Example:
                      ta search --archive ~/Zettelkasten --tag learning
                    """
            case .notADirectory(let path):
                return """
                    Archive path is not a directory: \(path)
                    Verify with 'ls' that the path exists and is a folder of .md files.
                    """
            }
        }
    }

    let flagValue: String?
    let environment: [String: String]
    let configFileReader: (URL) -> String?

    public init(
        flagValue: String?,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        configFileReader: @escaping (URL) -> String? = Self.defaultConfigReader
    ) {
        self.flagValue = flagValue
        self.environment = environment
        self.configFileReader = configFileReader
    }

    func resolve() throws -> URL {
        try resolveConfig().archiveDirectory
    }

    public func resolveConfig() throws -> ResolvedConfig {
        let configPath = Self.defaultConfigPath()
        let configContents = configFileReader(configPath)
        let parsed = configContents.flatMap { Self.parseConfig(from: $0) }

        let archiveDirectory: URL
        let archiveSource: ResolvedConfig.ArchiveSource

        if let value = flagValue, !value.isEmpty {
            archiveDirectory = try validated(path: value)
            archiveSource = .flag
        } else if let value = environment["TA_DIR"], !value.isEmpty {
            archiveDirectory = try validated(path: value)
            archiveSource = .environment
        } else if let path = parsed?.archive {
            archiveDirectory = try validated(path: path)
            archiveSource = .configFile
        } else {
            throw Error.notConfigured(configPath: configPath.path)
        }

        let idPattern: IDPattern
        let idPatternSource: ResolvedConfig.IDPatternSource
        if let patternSource = parsed?.idPattern, let pattern = IDPattern(source: patternSource) {
            idPattern = pattern
            idPatternSource = .configFile
        } else {
            idPattern = .default
            idPatternSource = .builtInDefault
        }

        return ResolvedConfig(
            archiveDirectory: archiveDirectory,
            archiveSource: archiveSource,
            idPattern: idPattern,
            idPatternSource: idPatternSource
        )
    }

    private func validated(path raw: String) throws -> URL {
        let expanded = (raw as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue else {
            throw Error.notADirectory(expanded)
        }
        return URL(filePath: expanded, directoryHint: .isDirectory).resolvingSymlinksInPath()
    }

    static func defaultConfigPath() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appending(path: ".config/ta/config.yaml")
    }

    public static let defaultConfigReader: @Sendable (URL) -> String? = { url in
        try? String(contentsOf: url, encoding: .utf8)
    }

    private static func parseConfig(from yaml: String) -> (archive: String?, idPattern: String?)? {
        guard let parsed = try? Yams.load(yaml: yaml) as? [String: Any] else { return nil }
        return (parsed["archive"] as? String, parsed["id_pattern"] as? String)
    }
}
