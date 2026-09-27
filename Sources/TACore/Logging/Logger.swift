import Foundation

public struct Logger: Sendable {
    let enabled: Bool
    private let sink: @Sendable (String) -> Void

    public static let quiet = Logger(enabled: false)

    public init(enabled: Bool, sink: @escaping @Sendable (String) -> Void = standardErrorSink) {
        self.enabled = enabled
        self.sink = sink
    }

    public static func standardErrorSink(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        sink("[ta] \(message())")
    }
}
