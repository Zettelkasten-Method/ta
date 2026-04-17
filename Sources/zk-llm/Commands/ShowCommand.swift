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
        abstract: "Print the full body of one or more notes."
    )

    @Option(name: .customLong("archive"), help: "Path to the Zettelkasten archive.")
    var archive: String?

    @Argument(help: "One or more NoteRef (filename) values.")
    var refs: [String] = []

    func run() throws {
        guard !refs.isEmpty else {
            throw ValidationError("At least one ref is required.")
        }
        let archiveDir = try ArchiveResolver(flagValue: archive).resolve()
        let result = try ShowPipeline.run(
            archiveDirectory: archiveDir,
            refs: refs.map { NoteRef(filename: $0) }
        )
        print(result.output, terminator: "")
        if !result.anyResolved {
            throw ExitCode(1)
        }
    }
}
