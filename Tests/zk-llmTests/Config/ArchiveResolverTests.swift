// Tests/zk-llmTests/Config/ArchiveResolverTests.swift
import Testing
import Foundation
@testable import zk_llm

@Suite("ArchiveResolver")
struct ArchiveResolverTests {
    @Test("flag wins over env and config")
    func flagWins() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let resolver = ArchiveResolver(
            flagValue: tmp.path,
            environment: ["ZK_LLM_ARCHIVE": "/nonexistent-env"],
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
            environment: ["ZK_LLM_ARCHIVE": tmp.path],
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

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zk-llm-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
