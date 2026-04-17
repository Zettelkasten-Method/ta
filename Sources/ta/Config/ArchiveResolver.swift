// Sources/ta/Config/ArchiveResolver.swift
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
                      2. export TA_ARCHIVE=/path/to/archive
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

    public let flagValue: String?
    public let environment: [String: String]
    public let configFileReader: (URL) -> String?

    public init(
        flagValue: String?,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        configFileReader: @escaping (URL) -> String? = Self.defaultConfigReader
    ) {
        self.flagValue = flagValue
        self.environment = environment
        self.configFileReader = configFileReader
    }

    public func resolve() throws -> URL {
        if let value = flagValue, !value.isEmpty {
            return try validated(path: value)
        }
        if let value = environment["TA_ARCHIVE"], !value.isEmpty {
            return try validated(path: value)
        }
        let configPath = Self.defaultConfigPath()
        if let contents = configFileReader(configPath),
           let path = Self.parseArchiveKey(from: contents) {
            return try validated(path: path)
        }
        throw Error.notConfigured(configPath: configPath.path)
    }

    private func validated(path raw: String) throws -> URL {
        let expanded = (raw as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue else {
            throw Error.notADirectory(expanded)
        }
        return URL(fileURLWithPath: expanded, isDirectory: true).resolvingSymlinksInPath()
    }

    public static func defaultConfigPath() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/ta/config.yaml")
    }

    public static let defaultConfigReader: @Sendable (URL) -> String? = { url in
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func parseArchiveKey(from yaml: String) -> String? {
        guard let parsed = try? Yams.load(yaml: yaml) as? [String: Any] else { return nil }
        return parsed["archive"] as? String
    }
}
