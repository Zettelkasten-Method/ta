import Foundation

public enum ShowPipeline {
    public static func run(
        config: ResolvedConfig,
        refs: [NoteRef],
        logger: Logger = .quiet
    ) throws -> ShowEmitter.EmitResult {
        logger.log("archive: \(config.archiveDirectory.path) (source: \(config.archiveSource))")
        logger.log("id_pattern: /\(config.idPattern.source)/ (source: \(config.idPatternSource))")
        let index = try NoteIndex(archiveDirectory: config.archiveDirectory, idPattern: config.idPattern, logger: logger)
        let emitter = ShowEmitter(index: index, archiveDirectory: config.archiveDirectory)
        return try emitter.emitWithStatus(refs: refs)
    }
}
