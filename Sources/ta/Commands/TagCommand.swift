import Foundation
import ArgumentParser

struct TagCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tag",
        abstract: "Search for notes carrying a specific hashtag (convenience for 'search --tag').",
        discussion: """
        Pass the tag name without the leading '#'. Equivalent to 'search --tag NAME'.

        Examples:
          ta tag thinking
          ta tag mental-models --depth 2
        """
    )

    @OptionGroup var globalOptions: GlobalOptions

    @Option(name: .customLong("archive"), help: "Path to the Zettelkasten archive.")
    var archive: String?

    @Argument(help: "Tag name without the leading '#'.")
    var tagName: String

    @Option(name: .customLong("depth"), help: "Graph expansion depth (0–10, default 3).")
    var depth: Int = 3

    func run() throws {
        let config = try ArchiveResolver(flagValue: archive).resolveConfig()
        let logger = Logger(enabled: globalOptions.verbose)
        let yaml = try SearchPipeline.run(
            config: config,
            predicates: [.tag(tagName)],
            depth: depth,
            logger: logger
        )
        print(yaml, terminator: "")
    }
}
