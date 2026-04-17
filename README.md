# zk-llm

A command-line retrieval tool over a Zettelkasten archive, shaped for consumption by coding agents. Prototype.

See `docs/README.md` for the design documentation tree.

## Build

```bash
swift build -c release
```

The binary lands at `./.build/release/zk-llm`.

## Configure

Point `zk-llm` at your archive in one of these ways (listed in precedence order):

1. Pass `--archive /path/to/archive` on a subcommand (`search`, `tag`, or `show`). The flag is not accepted at the root.
2. `export ZK_LLM_ARCHIVE=/path/to/archive`.
3. Write `archive: /path/to/archive` to `~/.config/zk-llm/config.yaml`.

## Usage

### Search

```bash
zk-llm search --tag learning --phrase "second-order" --depth 3
```

Emits a flat YAML list of direct hits plus their outgoing-link neighborhood up to `--depth` hops (default 3, cap 10).

### Tag-only search (convenience)

```bash
zk-llm tag thinking --depth 2
```

### Show a note

```bash
zk-llm show "202503091430 Mental Models.md" "202503091431 Second Order Thinking.md"
```

Emits YAML frontmatter + raw markdown body per ref.

## Runtime dependencies

- `rg` (ripgrep) on `$PATH` is preferred.
- Falls back to `grep -l -r` if `rg` is absent.

## Tests

```bash
swift test
```
