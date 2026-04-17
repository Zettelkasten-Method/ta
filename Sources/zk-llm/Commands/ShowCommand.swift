// Sources/zk-llm/Commands/ShowCommand.swift
import Foundation
import ArgumentParser

public enum ShowPipeline {
    public static func run(archiveDirectory: URL, refs: [NoteRef]) throws -> ShowEmitter.EmitResult {
        let index = try NoteIndex(archiveDirectory: archiveDirectory)
        let emitter = ShowEmitter(index: index, archiveDirectory: archiveDirectory)
        return try emitter.emitWithStatus(refs: refs)
    }
}

struct ShowCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Print the full body of one or more notes.",
        discussion: """
        Each ref is a note's full filename (as emitted by 'search' or 'tag' in the
        'ref:' field). Output is YAML frontmatter per ref followed by raw markdown.
        Exit 0 if any ref resolved; exit 1 if none resolved.

        Examples:
          zk-llm show "202503091430 Mental Models.md"
          zk-llm show "202503091430 Mental Models.md" "202503091431 Second Order Thinking.md"
        """
    )

    @Option(name: .customLong("archive"), help: "Path to the Zettelkasten archive.")
    var archive: String?

    @Argument(help: "One or more NoteRef (filename) values.")
    var refs: [String] = []

    func run() throws {
        guard !refs.isEmpty else {
            throw ValidationError("""
                At least one ref is required. A ref is a note's full filename (including .md).
                Discover refs with 'zk-llm search' or 'zk-llm tag', then pass them to show.
                Example:
                  zk-llm show "202503091430 Mental Models.md"
                """)
        }
        let archiveDir = try ArchiveResolver(flagValue: archive).resolve()
        let result = try ShowPipeline.run(
            archiveDirectory: archiveDir,
            refs: refs.map { NoteRef(filename: $0) }
        )
        print(result.output, terminator: "")
        if !result.anyResolved {
            FileHandle.standardError.write(Data("""
                zk-llm: no refs resolved. A ref must be a full filename from the archive.
                Tip: run 'zk-llm search' or 'zk-llm tag' first to list valid refs.

                """.utf8))
            throw ExitCode(1)
        }
    }
}
