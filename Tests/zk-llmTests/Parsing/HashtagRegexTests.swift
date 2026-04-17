// Tests/zk-llmTests/Parsing/HashtagRegexTests.swift
import Testing
@testable import zk_llm

@Suite("HashtagRegex")
struct HashtagRegexTests {
    @Test("single leading-of-line tag")
    func singleLine() {
        #expect(HashtagRegex.extract(from: "#foo") == ["foo"])
    }

    @Test("multiple tags on one line")
    func multiple() {
        #expect(HashtagRegex.extract(from: "See #foo, #bar, and #baz.") == ["foo", "bar", "baz"])
    }

    @Test("pure-numeric tag")
    func numeric() {
        #expect(HashtagRegex.extract(from: "#2026") == ["2026"])
    }

    @Test("unicode letters allowed")
    func unicode() {
        #expect(HashtagRegex.extract(from: "#Ernährung #日本語") == ["Ernährung", "日本語"])
    }

    @Test("URL fragment is not a tag")
    func urlFragment() {
        #expect(HashtagRegex.extract(from: "https://example.com/page#section") == [])
    }

    @Test("word-adjacent hash is not a tag")
    func wordAdjacent() {
        #expect(HashtagRegex.extract(from: "word#tag") == [])
    }

    @Test("trailing punctuation is excluded")
    func trailingPunct() {
        #expect(HashtagRegex.extract(from: "#foo.") == ["foo"])
    }

    @Test("hyphen and underscore allowed mid-tag")
    func hyphenAndUnderscore() {
        #expect(HashtagRegex.extract(from: "#mental-models #well_known") == ["mental-models", "well_known"])
    }
}
