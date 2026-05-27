import Testing
import Foundation
@testable import ta

@Suite("Logger")
struct LoggerTests {
    @Test("enabled logger delivers messages to sink")
    func enabled() {
        var captured: [String] = []
        let logger = Logger(enabled: true) { captured.append($0) }
        logger.log("hello")
        logger.log("world")
        #expect(captured == ["[ta] hello", "[ta] world"])
    }

    @Test("disabled logger suppresses messages")
    func disabled() {
        var captured: [String] = []
        let logger = Logger(enabled: false) { captured.append($0) }
        logger.log("should not appear")
        #expect(captured.isEmpty)
    }

    @Test("quiet logger is disabled")
    func quiet() {
        #expect(Logger.quiet.enabled == false)
    }
}
