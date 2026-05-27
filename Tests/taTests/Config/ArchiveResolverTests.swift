// Tests/taTests/Config/ArchiveResolverTests.swift
import Testing
import Foundation
@testable import ta

@Suite("ArchiveResolver")
struct ArchiveResolverTests {
    @Test("flag wins over env and config")
    func flagWins() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let resolver = ArchiveResolver(
            flagValue: tmp.path,
            environment: ["TA_DIR": "/nonexistent-env"],
            configFileReader: { _ in "archive: /nonexistent-config\n" }
        )
        let resolved = try resolver.resolve()
        #expect(resolved.path == tmp.path)
    }

    @Test("env used when flag absent")
    func envUsed() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let resolver = ArchiveResolver(
            flagValue: nil,
            environment: ["TA_DIR": tmp.path],
            configFileReader: { _ in nil }
        )
        let resolved = try resolver.resolve()
        #expect(resolved.path == tmp.path)
    }

    @Test("config file used when env absent")
    func configUsed() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let resolver = ArchiveResolver(
            flagValue: nil,
            environment: [:],
            configFileReader: { _ in "archive: \(tmp.path)\n" }
        )
        let resolved = try resolver.resolve()
        #expect(resolved.path == tmp.path)
    }

    @Test("missing everywhere throws")
    func missing() throws {
        let resolver = ArchiveResolver(
            flagValue: nil,
            environment: [:],
            configFileReader: { _ in nil }
        )
        #expect(throws: ArchiveResolver.Error.self) {
            _ = try resolver.resolve()
        }
    }

    @Test("resolveConfig returns default IDPattern when not in config")
    func resolveConfigDefault() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let resolver = ArchiveResolver(
            flagValue: tmp.path,
            environment: [:],
            configFileReader: { _ in nil }
        )
        let config = try resolver.resolveConfig()
        #expect(config.archiveDirectory.path == tmp.path)
        #expect(config.idPattern == .default)
        #expect(config.idPatternSource == "default")
    }

    @Test("resolveConfig parses id_pattern from config YAML")
    func resolveConfigCustomPattern() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let resolver = ArchiveResolver(
            flagValue: tmp.path,
            environment: [:],
            configFileReader: { _ in "archive: /tmp\nid_pattern: \"\\\\d{14}\"\n" }
        )
        let config = try resolver.resolveConfig()
        #expect(config.idPattern.source == "\\d{14}")
        #expect(config.idPatternSource == "config")
    }

    @Test("resolveConfig falls back to default on invalid id_pattern")
    func resolveConfigInvalidPattern() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let resolver = ArchiveResolver(
            flagValue: tmp.path,
            environment: [:],
            configFileReader: { _ in "id_pattern: \"[\"\n" }
        )
        let config = try resolver.resolveConfig()
        #expect(config.idPattern == .default)
    }

    @Test("resolveConfig tracks archive provenance")
    func resolveConfigProvenance() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let fromFlag = ArchiveResolver(flagValue: tmp.path, environment: [:], configFileReader: { _ in nil })
        #expect(try fromFlag.resolveConfig().archiveSource == "flag")

        let fromEnv = ArchiveResolver(flagValue: nil, environment: ["TA_DIR": tmp.path], configFileReader: { _ in nil })
        #expect(try fromEnv.resolveConfig().archiveSource == "env")

        let fromConfig = ArchiveResolver(flagValue: nil, environment: [:], configFileReader: { _ in "archive: \(tmp.path)\n" })
        #expect(try fromConfig.resolveConfig().archiveSource == "config")
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
