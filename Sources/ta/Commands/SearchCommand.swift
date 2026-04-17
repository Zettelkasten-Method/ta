import Foundation
import ArgumentParser

public enum SearchPipeline {
    public enum Error: Swift.Error, CustomStringConvertible {
        case noPredicates

        public var description: String {
            switch self {
            case .noPredicates: return """
                At least one of --tag, --phrase, --word, or a positional phrase is required.
                Examples:
                  ta search --tag learning
                  ta search --phrase "second-order" --word inversion
                  ta search "mental models" --depth 2
                """
            }
        }
    }

    public static func run(
        archiveDirectory: URL,
        predicates: [RipgrepRunner.Predicate],
        depth: Int
    ) throws -> String {
        guard !predicates.isEmpty else { throw Error.noPredicates }

        let candidates = try RipgrepRunner().run(
            predicates: predicates,
            archiveDirectory: archiveDirectory
        )
        let index = try NoteIndex(archiveDirectory: archiveDirectory)
        let filter = StructuralFilter(index: index, archiveDirectory: archiveDirectory)
        let directHits = try filter.verify(candidates: candidates, predicates: predicates)
        let expander = GraphExpander(index: index, archiveDirectory: archiveDirectory)
        let all = try expander.expand(directHits: directHits, depth: depth)
        return SearchYAMLEmitter.emit(all)
    }
}

struct SearchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search the Zettelkasten with AND-combined predicates.",
        discussion: """
        Predicates combine with AND. Provide one or more of --tag, --phrase, --word,
        or a positional phrase. Results include direct hits (depth 0, with snippet)
        plus outgoing-link neighbors up to --depth hops (default 3, cap 10).

        Examples:
          ta search --tag learning
          ta search --tag thinking --phrase "second-order"
          ta search --word inversion --depth 2
          ta search "mental models"
        """
    )

    @Option(name: .customLong("archive"), help: "Path to the Zettelkasten archive.")
    var archive: String?

    @Option(name: .customLong("tag"), parsing: .singleValue, help: "Require #TAG (repeatable).")
    var tags: [String] = []

    @Option(name: .customLong("phrase"), parsing: .singleValue, help: "Require literal phrase (repeatable).")
    var phrases: [String] = []

    @Option(name: .customLong("word"), parsing: .singleValue, help: "Require whole-word match (repeatable).")
    var words: [String] = []

    @Option(name: .customLong("depth"), help: "Graph expansion depth (0–10, default 3).")
    var depth: Int = 3

    @Argument(help: "Optional implicit phrase predicate.")
    var positionalPhrase: String?

    func run() throws {
        let archiveDir = try ArchiveResolver(flagValue: archive).resolve()
        var predicates: [RipgrepRunner.Predicate] = []
        predicates += tags.map { .tag($0) }
        predicates += phrases.map { .phrase($0) }
        predicates += words.map { .word($0) }
        if let p = positionalPhrase, !p.isEmpty { predicates.append(.phrase(p)) }

        let yaml = try SearchPipeline.run(
            archiveDirectory: archiveDir,
            predicates: predicates,
            depth: depth
        )
        print(yaml, terminator: "")
    }
}
