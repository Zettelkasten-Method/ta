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
}
