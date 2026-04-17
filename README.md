# ta — the archive

A command-line retrieval tool over a Zettelkasten archive, shaped for consumption by coding agents. Prototype.

See `docs/README.md` for the design documentation tree.

## Build

```bash
swift build -c release
```

The binary lands at `./.build/release/ta`.

## Configure

Point `ta` at your archive in one of these ways (listed in precedence order):

1. Pass `--archive /path/to/archive` on a subcommand (`search`, `tag`, or `show`). The flag is not accepted at the root.
2. `export TA_DIR=/path/to/archive`.
3. Write `archive: /path/to/archive` to `~/.config/ta/config.yaml`.

## Usage

### Search

```bash
ta search --tag learning --phrase "second-order" --depth 3
```

Emits a flat YAML list of direct hits plus their outgoing-link neighborhood up to `--depth` hops (default 3, cap 10).

### Tag-only search (convenience)

```bash
ta tag thinking --depth 2
```

### Show a note

```bash
ta show "202503091430 Mental Models.md" "202503091431 Second Order Thinking.md"
```

Emits YAML frontmatter + raw markdown body per ref.

## Agent skills

`ta` is built for coding agents that drive the CLI on the user's behalf. Copy-pasteable skills live under [`docs/skills/`](docs/skills/):

| Skill | Triggers on | Strategy |
|---|---|---|
| `ta-search` | Literal lookups. "Find my note about X." | Single query, read YAML, call `show` if needed. |
| `ta-associative-recall` | Fuzzy / vibe queries. "That idea I had about..." | Fan out 5–8 literal probes across tag / phrase / word axes, aggregate, rank, offer pivots. |
| `ta-deep-research` | Topic exploration. "Trace X through my notes." | Graph crawl + selective `show` + iterative extraction + synthesis with citations. |

Claude Code users:

```bash
cp -r docs/skills/ta-search ~/.claude/skills/
cp -r docs/skills/ta-associative-recall ~/.claude/skills/
cp -r docs/skills/ta-deep-research ~/.claude/skills/
```

Other agents: see [`docs/skills/README.md`](docs/skills/README.md) for the frontmatter convention.

## Runtime dependencies

- `rg` (ripgrep) on `$PATH` is preferred.
- Falls back to `grep -l -r` if `rg` is absent.

## Tests

```bash
swift test
```
