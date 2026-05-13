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
        #expect(names == ["delta.md"])
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
