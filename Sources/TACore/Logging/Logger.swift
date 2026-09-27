import Foundation

public struct Logger: @unchecked Sendable {
    public let enabled: Bool
    private let sink: (String) -> Void

    public static let quiet = Logger(enabled: false)

    public init(enabled: Bool, sink: @escaping (String) -> Void = defaultSink) {
        self.enabled = enabled
        self.sink = sink
    }

    public func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        sink("[ta] \(message())")
    }
}

@usableFromInline func defaultSink(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}
