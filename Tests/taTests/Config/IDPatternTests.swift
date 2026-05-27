import Testing
import Foundation
@testable import ta

@Suite("IDPattern")
struct IDPatternTests {
    @Test("default pattern uses \\d{12}")
    func defaultPattern() {
        #expect(IDPattern.default.source == "\\d{12}")
    }

    @Test("extracts 12-digit prefix ID")
    func prefixExtraction() {
        let ids = IDPattern.default.extractIDs(from: "202503091430 Mental Models")
        #expect(ids == ["202503091430"])
    }

    @Test("returns empty for filename with no digits")
    func noMatch() {
        let ids = IDPattern.default.extractIDs(from: "No Digits Here")
        #expect(ids == [])
    }

    @Test("invalid regex source returns nil")
    func invalidRegex() {
        #expect(IDPattern(source: "[invalid") == nil)
    }

    @Test("extracts 12-digit suffix ID")
    func suffixExtraction() {
        let ids = IDPattern.default.extractIDs(from: "Thinking About Thinking 202506252102")
        #expect(ids == ["202506252102"])
    }

    @Test("extracts ID after separator")
    func separatorExtraction() {
        let ids = IDPattern.default.extractIDs(from: "My Note - 202506252102")
        #expect(ids == ["202506252102"])
    }

    @Test("extracts multiple IDs left to right")
    func multiMatch() {
        let ids = IDPattern.default.extractIDs(from: "202501011200 cross-ref 202501011201")
        #expect(ids == ["202501011200", "202501011201"])
    }
}
