import Foundation
import Markdown

public enum NonCodeTextExtractor {
    public static func extract(from document: Document) -> String {
        var buffer = ""
        var walker = Walker(buffer: "")
        walker.visit(document)
        buffer = walker.buffer
        return buffer
    }

    private struct Walker: MarkupWalker {
        var buffer: String

        mutating func visitText(_ text: Text) {
            buffer += text.string
        }

        mutating func visitInlineCode(_ inlineCode: InlineCode) {
        }

        mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        }

        mutating func visitHTMLBlock(_ html: HTMLBlock) {
        }

        mutating func visitInlineHTML(_ html: InlineHTML) {
        }

        mutating func visitSoftBreak(_ softBreak: SoftBreak) {
            buffer += " "
        }

        mutating func visitLineBreak(_ lineBreak: LineBreak) {
            buffer += "\n"
        }

        mutating func defaultVisit(_ markup: Markup) {
            for child in markup.children {
                visit(child)
            }
            if markup is Paragraph || markup is Heading || markup is BlockQuote
                || markup is ListItem || markup is CodeBlock
            {
                buffer += "\n"
            }
        }
    }
}
