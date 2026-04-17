import ArgumentParser

@main
struct ZkLlm: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zk-llm",
        abstract: "Zettelkasten retrieval CLI for coding agents.",
        discussion: """
        EXAMPLES:
          Find notes by tag, expand 1 hop along wiki-links:
            zk-llm search --tag learning --depth 1

          AND-combine predicates (tag + phrase + whole word):
            zk-llm search --tag thinking --phrase "second-order" --word inversion

          Positional phrase shortcut:
            zk-llm search "mental models" --depth 2

          Tag-only convenience:
            zk-llm tag thinking --depth 2

          Print one or more notes (frontmatter + raw markdown):
            zk-llm show "202503091430 Mental Models.md"

        Configure the archive once via --archive, ZK_LLM_ARCHIVE, or
        ~/.config/zk-llm/config.yaml (key: archive).
        """,
        version: "0.0.1",
        subcommands: [SearchCommand.self, TagCommand.self, ShowCommand.self],
        defaultSubcommand: nil
    )
}
