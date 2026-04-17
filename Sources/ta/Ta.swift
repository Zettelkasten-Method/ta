import ArgumentParser

@main
struct Ta: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ta",
        abstract: "Zettelkasten retrieval CLI for coding agents.",
        discussion: """
        EXAMPLES:
          Find notes by tag, expand 1 hop along wiki-links:
            ta search --tag learning --depth 1

          AND-combine predicates (tag + phrase + whole word):
            ta search --tag thinking --phrase "second-order" --word inversion

          Positional phrase shortcut:
            ta search "mental models" --depth 2

          Tag-only convenience:
            ta tag thinking --depth 2

          Print one or more notes (frontmatter + raw markdown):
            ta show "202503091430 Mental Models.md"

        Archive path resolution (highest precedence first):
          1. --archive PATH  — flag on a subcommand (search, tag, or show)
          2. TA_ARCHIVE  — environment variable
          3. archive: PATH   — key in ~/.config/ta/config.yaml
        """,
        version: "0.0.1",
        subcommands: [SearchCommand.self, TagCommand.self, ShowCommand.self],
        defaultSubcommand: nil
    )
}
