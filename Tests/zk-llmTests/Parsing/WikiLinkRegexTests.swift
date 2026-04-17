import Testing
@testable import zk_llm

@Suite("WikiLinkRegex")
struct WikiLinkRegexTests {
    @Test("bare ID link")
    func bareId() {
        #expect(WikiLinkRegex.extractTargets(from: "See [[202503091430]].") == ["202503091430"])
    }

    @Test("link with anchor text is stripped")
    func withAnchor() {
        #expect(WikiLinkRegex.extractTargets(from: "See [[202503091430|Display Text]].") == ["202503091430"])
    }

    @Test("multiple links on one line")
    func multiple() {
        #expect(WikiLinkRegex.extractTargets(from: "[[a]] and [[b]]") == ["a", "b"])
    }

    @Test("unclosed is not a match")
    func unclosed() {
        #expect(WikiLinkRegex.extractTargets(from: "[[unclosed") == [])
    }

    @Test("single brackets are not wiki-links")
    func singleBracket() {
        #expect(WikiLinkRegex.extractTargets(from: "[foo] and [bar](http://x)") == [])
    }

    @Test("newline inside link is rejected")
    func newline() {
        #expect(WikiLinkRegex.extractTargets(from: "[[a\nb]]") == [])
    }

    @Test("duplicate targets are deduped in document order")
    func deduped() {
        #expect(WikiLinkRegex.extractTargets(from: "[[a]] [[b]] [[a]]") == ["a", "b"])
    }
}
