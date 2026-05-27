import ArgumentParser

struct GlobalOptions: ParsableArguments {
    @Flag(name: .customLong("verbose"), help: "Log pipeline diagnostics to stderr.")
    var verbose: Bool = false
}
