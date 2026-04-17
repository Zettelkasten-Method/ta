// Sources/ta/Pipeline/RipgrepRunner.swift
import Foundation

public struct RipgrepRunner {
    public enum Predicate: Sendable, Equatable {
        case tag(String)
        case phrase(String)
        case word(String)
    }

    public enum Error: Swift.Error, CustomStringConvertible {
        case toolFailed(String, Int32)
        case toolNotFound

        public var description: String {
            switch self {
            case .toolFailed(let cmd, let code):
                return """
                    Search tool failed (exit \(code)): \(cmd)
                    Check that the archive path is readable and contains .md files.
                    """
            case .toolNotFound:
                return """
                    Neither 'rg' (ripgrep) nor 'grep' was found on PATH.
                    Install ripgrep:
                      macOS:  brew install ripgrep
                      Linux:  apt install ripgrep  (or equivalent)
                    """
            }
        }
    }

    public init() {}

    public func run(predicates: [Predicate], archiveDirectory: URL) throws -> [NoteRef] {
        guard !predicates.isEmpty else { return [] }
        let useRipgrep = Self.hasTool("rg")
        var intersection: Set<String>? = nil
        for predicate in predicates {
            let files = try runOne(predicate: predicate, in: archiveDirectory, useRipgrep: useRipgrep)
            if var acc = intersection {
                acc.formIntersection(files)
                intersection = acc
            } else {
                intersection = files
            }
            if intersection?.isEmpty == true { break }
        }
        let names = (intersection ?? []).sorted()
        return names.map { NoteRef(filename: $0) }
    }

    private func runOne(
        predicate: Predicate,
        in archive: URL,
        useRipgrep: Bool
    ) throws -> Set<String> {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.standardOutput = pipe
        process.standardError = FileHandle(forReadingAtPath: "/dev/null") ?? FileHandle.nullDevice

        let args: [String]
        if useRipgrep {
            switch predicate {
            case .tag(let tag):
                args = ["rg", "-l", "--type", "md", "--", "#\(tag)\\b", archive.path]
            case .phrase(let phrase):
                args = ["rg", "-l", "-F", "--type", "md", "--", phrase, archive.path]
            case .word(let word):
                args = ["rg", "-l", "-w", "-F", "--type", "md", "--", word, archive.path]
            }
        } else {
            switch predicate {
            case .tag(let tag):
                args = ["grep", "-l", "-r", "--include=*.md", "-E", "#\(tag)([^[:alnum:]_-]|$)", archive.path]
            case .phrase(let phrase):
                args = ["grep", "-l", "-r", "--include=*.md", "-F", phrase, archive.path]
            case .word(let word):
                args = ["grep", "-l", "-r", "--include=*.md", "-w", "-F", word, archive.path]
            }
        }
        process.arguments = args

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        // rg/grep exit code 1 means "no matches", which is not an error.
        if process.terminationStatus > 1 {
            throw Error.toolFailed(args.joined(separator: " "), process.terminationStatus)
        }
        let output = String(data: data, encoding: .utf8) ?? ""
        var set = Set<String>()
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let path = String(line)
            // rg/grep return absolute or archive-relative paths. Reduce to filename.
            let url = URL(fileURLWithPath: path)
            set.insert(url.lastPathComponent)
        }
        return set
    }

    private static func hasTool(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = ["which", name]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
