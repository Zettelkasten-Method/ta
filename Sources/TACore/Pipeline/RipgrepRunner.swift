// Sources/TACore/Pipeline/RipgrepRunner.swift
import Foundation

struct RipgrepRunner {
    enum Error: Swift.Error, CustomStringConvertible {
        case toolFailed(String, Int32)
        case toolNotFound
        case patternContainsNewline(String)

        var description: String {
            switch self {
            case .toolFailed(let cmd, let code):
                return """
                    Search tool failed (exit \(code)): \(cmd)
                    Check that the archive path is readable and contains .md or .txt files.
                    """
            case .toolNotFound:
                return """
                    Neither 'rg' (ripgrep) nor 'grep' was found on PATH.
                    Install ripgrep:
                      macOS:  brew install ripgrep
                      Linux:  apt install ripgrep  (or equivalent)
                    """
            case .patternContainsNewline(let pattern):
                return "Search terms cannot span lines: \(pattern.debugDescription)"
            }
        }
    }

    private let environment: [String: String]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    func run(predicates: [SearchPredicate], archiveDirectory: URL, logger: Logger = .quiet) throws -> [NoteRef] {
        guard !predicates.isEmpty else { return [] }
        var intersection: Set<String>? = nil
        for predicate in predicates {
            logger.log("search: \(predicate) ...")
            let files = try runOne(predicate: predicate, in: archiveDirectory)
            logger.log("search: \(files.count) matches for \(predicate)")
            if var acc = intersection {
                acc.formIntersection(files)
                intersection = acc
            } else {
                intersection = files
            }
            if intersection?.isEmpty == true { break }
        }
        let names = (intersection ?? []).sorted()
        logger.log("search: \(names.count) candidates after intersection")
        return names.map { NoteRef(filename: $0) }
    }

    private enum Tool: CaseIterable { case rg, grep }

    private func runOne(predicate: SearchPredicate, in archive: URL) throws -> Set<String> {
        for tool in Tool.allCases {
            if let files = try search(predicate: predicate, in: archive, with: tool) { return files }
        }
        throw Error.toolNotFound
    }

    /// Matching filenames, or nil when `tool` is not on PATH.
    private func search(predicate: SearchPredicate, in archive: URL, with tool: Tool) throws -> Set<String>? {
        let term: String
        switch predicate {
        case .tag(let t), .phrase(let t), .word(let t): term = t
        }
        // rg and grep match line by line, so a multi-line term can never match; `-f -` would also split it.
        guard !term.contains(where: \.isNewline) else { throw Error.patternContainsNewline(term) }

        let rgGlobs = NoteIndex.supportedExtensions.flatMap { ["-g", "*.\($0)"] }
        let grepIncludes = NoteIndex.supportedExtensions.map { "--include=*.\($0)" }
        let args: [String]
        let toPattern: (String) -> String
        switch (tool, predicate) {
        case (.rg, .tag):
            args = ["rg", "-l", "-i"] + rgGlobs
            toPattern = { "#\($0)\\b" }
        case (.rg, .phrase):
            args = ["rg", "-l", "-i", "-F"] + rgGlobs
            toPattern = { $0 }
        case (.rg, .word):
            args = ["rg", "-l", "-i", "-w", "-F"] + rgGlobs
            toPattern = { $0 }
        case (.grep, .tag):
            args = ["grep", "-l", "-r", "-i"] + grepIncludes + ["-E"]
            toPattern = { "#\($0)([^[:alnum:]_-]|$)" }
        case (.grep, .phrase):
            args = ["grep", "-l", "-r", "-i"] + grepIncludes + ["-F"]
            toPattern = { $0 }
        case (.grep, .word):
            args = ["grep", "-l", "-r", "-i"] + grepIncludes + ["-w", "-F"]
            toPattern = { $0 }
        }
        let patterns = Self.normalizationVariants(of: term).map(toPattern)

        let process = Process()
        let stdout = Pipe()
        let stdin = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.environment = environment
        // Patterns go through stdin because Process converts argv to NFD, which misses NFC note bodies.
        process.arguments = args + ["-f", "-", "--", archive.path]
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle(forReadingAtPath: "/dev/null") ?? FileHandle.nullDevice

        let stdinHandle = stdin.fileHandleForWriting
        // env exits at once when the tool is missing; a write to the closed pipe must fail, not kill us.
        _ = fcntl(stdinHandle.fileDescriptor, F_SETNOSIGPIPE, 1)
        try process.run()
        try? stdinHandle.write(contentsOf: Data(patterns.map { $0 + "\n" }.joined().utf8))
        try? stdinHandle.close()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let commandNotFound: Int32 = 127
        if process.terminationStatus == commandNotFound { return nil }
        if process.terminationStatus > 1 {
            let command = (process.arguments ?? []).joined(separator: " ")
            throw Error.toolFailed("\(command) <<< \(patterns)", process.terminationStatus)
        }
        let output = String(data: data, encoding: .utf8) ?? ""
        var set = Set<String>()
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let path = String(line)
            let url = URL(fileURLWithPath: path)
            set.insert(url.lastPathComponent)
        }
        return set
    }

    /// The NFC and NFD forms of `term`, deduplicated; rg ORs them so either body normalization matches.
    private static func normalizationVariants(of term: String) -> [String] {
        let nfc = term.precomposedStringWithCanonicalMapping
        let nfd = term.decomposedStringWithCanonicalMapping
        return nfc.utf8.elementsEqual(nfd.utf8) ? [nfc] : [nfc, nfd]
    }
}
