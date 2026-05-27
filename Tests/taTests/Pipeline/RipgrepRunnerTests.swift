// Tests/taTests/Pipeline/RipgrepRunnerTests.swift
import Testing
import Foundation
@testable import ta

@Suite("RipgrepRunner")
struct RipgrepRunnerTests {
    private func makeTempArchive() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-rg-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Alpha\nFoo has #learning tag".write(
            to: root.appendingPathComponent("alpha.md"), atomically: true, encoding: .utf8)
        try "# Beta\nBar has #thinking".write(
            to: root.appendingPathComponent("beta.md"), atomically: true, encoding: .utf8)
        try "# Gamma\nBoth #learning and #thinking".write(
            to: root.appendingPathComponent("gamma.md"), atomically: true, encoding: .utf8)
        return root
    }

    @Test("tag predicate returns matching files")
    func tag() throws {
        let root = try makeTempArchive()
        defer { try? FileManager.default.removeItem(at: root) }
        let runner = RipgrepRunner()
        let refs = try runner.run(
            predicates: [.tag("learning")],
            archiveDirectory: root
        )
        let names = Set(refs.map(\.filename))
        #expect(names == ["alpha.md", "gamma.md"])
    }

    @Test("multiple predicates are AND-intersected")
    func andIntersect() throws {
        let root = try makeTempArchive()
        defer { try? FileManager.default.removeItem(at: root) }
        let runner = RipgrepRunner()
        let refs = try runner.run(
            predicates: [.tag("learning"), .tag("thinking")],
            archiveDirectory: root
        )
        let names = Set(refs.map(\.filename))
        #expect(names == ["gamma.md"])
    }

    @Test("phrase predicate")
    func phrase() throws {
        let root = try makeTempArchive()
        defer { try? FileManager.default.removeItem(at: root) }
        let runner = RipgrepRunner()
        let refs = try runner.run(
            predicates: [.phrase("Bar has")],
            archiveDirectory: root
        )
        let names = Set(refs.map(\.filename))
        #expect(names == ["beta.md"])
    }

    @Test("word predicate respects word boundaries")
    func word() throws {
        let root = try makeTempArchive()
        defer { try? FileManager.default.removeItem(at: root) }
        let extra = root.appendingPathComponent("delta.md")
        try "Foobar should not match the word foo".write(to: extra, atomically: true, encoding: .utf8)
        let runner = RipgrepRunner()
        let refs = try runner.run(
            predicates: [.word("foo")],
            archiveDirectory: root
        )
        let names = Set(refs.map(\.filename))
        // Matches "foo" in delta.md and case-insensitively "Foo" in alpha.md/gamma.md
        // but NOT "Foobar" (word boundary).
        #expect(names == ["alpha.md", "delta.md"])
    }

    @Test("matches are case-insensitive")
    func caseInsensitive() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-rg-ci-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "A `LSUIElement` line and #MacOS tag.".write(
            to: root.appendingPathComponent("note.md"), atomically: true, encoding: .utf8)
        let runner = RipgrepRunner()
        let phraseRefs = try runner.run(predicates: [.phrase("lsuielement")], archiveDirectory: root)
        #expect(Set(phraseRefs.map(\.filename)) == ["note.md"])
        let wordRefs = try runner.run(predicates: [.word("LSUIELEMENT")], archiveDirectory: root)
        #expect(Set(wordRefs.map(\.filename)) == ["note.md"])
        let tagRefs = try runner.run(predicates: [.tag("macos")], archiveDirectory: root)
        #expect(Set(tagRefs.map(\.filename)) == ["note.md"])
    }

    @Test("matches inside .txt files")
    func txtFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-rg-txt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "phrase target inside text file".write(
            to: root.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)
        try "phrase target inside markdown file".write(
            to: root.appendingPathComponent("note.md"), atomically: true, encoding: .utf8)
        let runner = RipgrepRunner()
        let phraseRefs = try runner.run(predicates: [.phrase("phrase target")], archiveDirectory: root)
        #expect(Set(phraseRefs.map(\.filename)) == ["note.md", "note.txt"])
        let wordRefs = try runner.run(predicates: [.word("target")], archiveDirectory: root)
        #expect(Set(wordRefs.map(\.filename)) == ["note.md", "note.txt"])
    }

    @Test("verbose logger captures command and match count")
    func verboseLogging() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-rg-verbose-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "Hello world #test".write(
            to: tmp.appendingPathComponent("111111111111 note.md"),
            atomically: true, encoding: .utf8)
        var messages: [String] = []
        let logger = Logger(enabled: true) { messages.append($0) }
        _ = try RipgrepRunner().run(
            predicates: [.tag("test")],
            archiveDirectory: tmp,
            logger: logger
        )
        #expect(messages.contains { $0.contains("predicate") || $0.contains("match") })
    }

    @Test("zero results are fine")
    func zero() throws {
        let root = try makeTempArchive()
        defer { try? FileManager.default.removeItem(at: root) }
        let runner = RipgrepRunner()
        let refs = try runner.run(
            predicates: [.phrase("absolutely-not-present")],
            archiveDirectory: root
        )
        #expect(refs.isEmpty)
    }
}
