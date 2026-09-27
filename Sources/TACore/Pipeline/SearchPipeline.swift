import Foundation

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
        config: ResolvedConfig,
        predicates: [SearchPredicate],
        depth: Int,
        logger: Logger = .quiet
    ) throws -> String {
        guard !predicates.isEmpty else { throw Error.noPredicates }

        logger.log("archive: \(config.archiveDirectory.path) (source: \(config.archiveSource))")
        logger.log("id_pattern: /\(config.idPattern.source)/ (source: \(config.idPatternSource))")
        let candidates = try RipgrepRunner().run(predicates: predicates, archiveDirectory: config.archiveDirectory, logger: logger)
        let index = try NoteIndex(archiveDirectory: config.archiveDirectory, idPattern: config.idPattern, logger: logger)
        let filter = StructuralFilter(index: index, archiveDirectory: config.archiveDirectory, logger: logger)
        let directHits = try filter.verify(candidates: candidates, predicates: predicates)
        let expander = GraphExpander(index: index, archiveDirectory: config.archiveDirectory, logger: logger)
        let all = try expander.expand(directHits: directHits, depth: depth)
        return SearchYAMLEmitter.emit(all)
    }
}
