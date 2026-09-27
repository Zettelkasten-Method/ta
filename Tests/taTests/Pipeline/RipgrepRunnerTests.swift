// Tests/taTests/Pipeline/RipgrepRunnerTests.swift
import Testing
import Foundation
@testable import TACore

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
        let log = LogCapture()
        let logger = log.logger()
        _ = try RipgrepRunner().run(
            predicates: [.tag("test")],
            archiveDirectory: tmp,
            logger: logger
        )
        #expect(log.messages.contains { $0.contains("predicate") || $0.contains("match") })
    }

    private func makeUmlautArchive(body: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ta-rg-umlaut-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(body.utf8).write(to: root.appendingPathComponent("note.md"))
        try Data("Nothing relevant here".utf8).write(to: root.appendingPathComponent("other.md"))
        return root
    }

    // Literals below use \u{...} escapes so NFC and NFD forms survive editor normalization.
    private static let nfcBody = "Die Kr\u{E4}fte in den St\u{E4}ndern, siehe #gr\u{F6}\u{DF}e"

    @Test("NFC phrase with umlaut finds NFC body")
    func umlautPhrase() throws {
        let root = try makeUmlautArchive(body: Self.nfcBody)
        defer { try? FileManager.default.removeItem(at: root) }
        let refs = try RipgrepRunner().run(predicates: [.phrase("St\u{E4}nder")], archiveDirectory: root)
        #expect(Set(refs.map(\.filename)) == ["note.md"])
    }

    @Test("NFC word with umlaut finds NFC body")
    func umlautWord() throws {
        let root = try makeUmlautArchive(body: Self.nfcBody)
        defer { try? FileManager.default.removeItem(at: root) }
        let refs = try RipgrepRunner().run(predicates: [.word("Kr\u{E4}fte")], archiveDirectory: root)
        #expect(Set(refs.map(\.filename)) == ["note.md"])
    }

    @Test("NFC tag with umlaut and sharp s finds NFC body")
    func umlautTag() throws {
        let root = try makeUmlautArchive(body: Self.nfcBody)
        defer { try? FileManager.default.removeItem(at: root) }
        let refs = try RipgrepRunner().run(predicates: [.tag("gr\u{F6}\u{DF}e")], archiveDirectory: root)
        #expect(Set(refs.map(\.filename)) == ["note.md"])
    }

    @Test("NFD query finds NFC body")
    func nfdQueryNFCBody() throws {
        let root = try makeUmlautArchive(body: Self.nfcBody)
        defer { try? FileManager.default.removeItem(at: root) }
        let refs = try RipgrepRunner().run(predicates: [.phrase("Sta\u{308}nder")], archiveDirectory: root)
        #expect(Set(refs.map(\.filename)) == ["note.md"])
    }

    @Test("NFC query finds NFD body")
    func nfcQueryNFDBody() throws {
        let root = try makeUmlautArchive(body: "Die Sta\u{308}ndern")
        defer { try? FileManager.default.removeItem(at: root) }
        let refs = try RipgrepRunner().run(predicates: [.phrase("St\u{E4}nder")], archiveDirectory: root)
        #expect(Set(refs.map(\.filename)) == ["note.md"])
    }

    @Test("pattern containing a newline is rejected")
    func newlineRejected() throws {
        let root = try makeUmlautArchive(body: Self.nfcBody)
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: RipgrepRunner.Error.self) {
            try RipgrepRunner().run(predicates: [.phrase("Die\nnote")], archiveDirectory: root)
        }
    }

    @Test("falls back to grep when rg is not on PATH", arguments: [
        (SearchPredicate.tag("learning"), Set(["alpha.md", "gamma.md"])),
        (.phrase("Bar has"), Set(["beta.md"])),
        (.word("foo"), Set(["alpha.md"])),
    ])
    func grepFallback(predicate: SearchPredicate, expected: Set<String>) throws {
        let root = try makeTempArchive()
        defer { try? FileManager.default.removeItem(at: root) }
        let refs = try RipgrepRunner(environment: ["PATH": "/usr/bin:/bin"])
            .run(predicates: [predicate], archiveDirectory: root)
        #expect(Set(refs.map(\.filename)) == expected)
    }

    @Test("neither rg nor grep on PATH throws toolNotFound")
    func toolNotFound() throws {
        let root = try makeTempArchive()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect {
            try RipgrepRunner(environment: ["PATH": "/nonexistent"])
                .run(predicates: [.phrase("Foo")], archiveDirectory: root)
        } throws: { error in
            guard case RipgrepRunner.Error.toolNotFound = error else { return false }
            return true
        }
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
