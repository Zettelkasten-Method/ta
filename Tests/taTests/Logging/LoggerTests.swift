import Testing
import Foundation
@testable import TACore

@Suite("Logger")
struct LoggerTests {
    @Test("enabled logger delivers messages to sink")
    func enabled() {
        let log = LogCapture()
        let logger = log.logger()
        logger.log("hello")
        logger.log("world")
        #expect(log.messages == ["[ta] hello", "[ta] world"])
    }

    @Test("disabled logger suppresses messages")
    func disabled() {
        let log = LogCapture()
        let logger = log.logger(enabled: false)
        logger.log("should not appear")
        #expect(log.messages.isEmpty)
    }

    @Test("quiet logger is disabled")
    func quiet() {
        #expect(Logger.quiet.enabled == false)
    }
}
