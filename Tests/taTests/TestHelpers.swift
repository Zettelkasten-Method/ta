import Foundation
import struct os.OSAllocatedUnfairLock
@testable import TACore

func makeFixtureConfig(_ url: URL) -> ResolvedConfig {
    ResolvedConfig(
        archiveDirectory: url,
        archiveSource: .flag,
        idPattern: .default,
        idPatternSource: .builtInDefault
    )
}

final class LogCapture: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: [String]())

    var messages: [String] { storage.withLock { $0 } }

    func logger(enabled: Bool = true) -> Logger {
        Logger(enabled: enabled) { line in self.storage.withLock { $0.append(line) } }
    }

    func removeAll() {
        storage.withLock { $0.removeAll() }
    }
}
