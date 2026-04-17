import Testing
@testable import zk_llm

@Suite("SearchYAMLEmitter")
struct SearchYAMLEmitterTests {
    @Test("empty result is '[]' on a single line")
    func empty() {
        let out = SearchYAMLEmitter.emit([])
        #expect(out == "[]\n")
    }

    @Test("single direct hit emits all fields")
    func singleHit() {
        let note = ParsedNote(
            ref: NoteRef(filename: "202503091430 Mental Models.md"),
            title: "Mental Models",
            timestampID: "202503091430",
            outgoingLinks: [NoteRef(filename: "202503091431 Second Order Thinking.md")],
            unresolvedLinkText: [],
            tags: ["learning", "thinking"],
            nonCodeText: ""
        )
        let hit = SearchHit(note: note, depth: 0, via: nil, snippet: "second-order thinking")
        let out = SearchYAMLEmitter.emit([hit])
        #expect(out.contains("ref: \"202503091430 Mental Models.md\""))
        #expect(out.contains("title: \"Mental Models\""))
        #expect(out.contains("snippet: \"second-order thinking\""))
        #expect(out.contains("tags: [learning, thinking]"))
        #expect(out.contains("links: [\"202503091431 Second Order Thinking.md\"]"))
        #expect(out.contains("depth: 0"))
        #expect(out.contains("via: null"))
    }

    @Test("expansion node has via and no snippet")
    func expansionNode() {
        let note = ParsedNote(
            ref: NoteRef(filename: "202503091431 Second Order Thinking.md"),
            title: "Second Order Thinking",
            timestampID: "202503091431",
            outgoingLinks: [],
            unresolvedLinkText: [],
            tags: ["thinking"],
            nonCodeText: ""
        )
        let hit = SearchHit(
            note: note,
            depth: 1,
            via: NoteRef(filename: "202503091430 Mental Models.md"),
            snippet: nil
        )
        let out = SearchYAMLEmitter.emit([hit])
        #expect(out.contains("depth: 1"))
        #expect(out.contains("via: \"202503091430 Mental Models.md\""))
        #expect(!out.contains("snippet:"))
    }
}
