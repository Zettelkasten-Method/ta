import ArgumentParser

@main
struct ZkLlm: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zk-llm",
        abstract: "Zettelkasten retrieval CLI for coding agents.",
        version: "0.0.1",
        subcommands: [SearchCommand.self, TagCommand.self, ShowCommand.self],
        defaultSubcommand: nil
    )
}
