import Testing
import Markdown
@testable import zk_llm

@Suite("NonCodeTextExtractor")
struct NonCodeTextExtractorTests {
    private func extract(_ source: String) -> String {
        let doc = Document(parsing: source)
        return NonCodeTextExtractor.extract(from: doc)
    }

    @Test("paragraph text included")
    func paragraph() {
        let text = extract("Hello world.")
        #expect(text.contains("Hello world."))
    }

    @Test("fenced code block is excluded")
    func fencedCode() {
        let source = """
        Outside text.

        ```
        #fake-tag inside fence
        ```

        More outside.
        """
        let text = extract(source)
        #expect(text.contains("Outside text."))
        #expect(text.contains("More outside."))
        #expect(!text.contains("#fake-tag"))
    }

    @Test("indented code block is excluded")
    func indentedCode() {
        let source = """
        Before.

            #fake-tag indented-code

        After.
        """
        let text = extract(source)
        #expect(text.contains("Before."))
        #expect(text.contains("After."))
        #expect(!text.contains("#fake-tag"))
    }

    @Test("inline code is excluded")
    func inlineCode() {
        let source = "Visible text with `#fake-tag` inline code."
        let text = extract(source)
        #expect(text.contains("Visible text"))
        #expect(text.contains("inline code"))
        #expect(!text.contains("#fake-tag"))
    }

    @Test("heading content included, heading marker excluded")
    func heading() {
        let text = extract("# My Heading")
        #expect(text.contains("My Heading"))
    }

    @Test("blockquote included")
    func blockquote() {
        let text = extract("> quoted #realtag text")
        #expect(text.contains("#realtag"))
    }

    @Test("list item included")
    func listItem() {
        let text = extract("- item one #realtag\n- item two")
        #expect(text.contains("#realtag"))
        #expect(text.contains("item two"))
    }

    @Test("emphasis content included")
    func emphasis() {
        let text = extract("_emphasised #realtag here_")
        #expect(text.contains("#realtag"))
    }
}
