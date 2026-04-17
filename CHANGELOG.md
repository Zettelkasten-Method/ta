# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-17

First prototype release of `ta` — a command-line retrieval tool over a Zettelkasten archive, shaped for coding agents.

### Added

- **`ta search` subcommand** — AND-combined predicates (`--tag`, `--phrase`, `--word`, positional phrase), `--depth N` graph expansion (default 3, cap 10). Emits flat YAML list of hits with `ref`, `title`, `snippet`, `tags`, `links`, `depth`, `via` fields per [ADR-004](docs/adrs/ADR-004--Search-Output-Flat-YAML.md).
- **`ta tag NAME` subcommand** — convenience for `ta search --tag NAME`.
- **`ta show REF...` subcommand** — emits YAML frontmatter + raw markdown body per ref, `---` delimited. Partial-success exit handling (exit 0 if any ref resolved, 1 if none) per [ADR-005](docs/adrs/ADR-005--Show-Output-Frontmatter-And-Raw-Markdown.md).
- **Cold-start pipeline** — ripgrep candidate selection → swift-markdown AST walk → hashtag and wiki-link regex extraction on non-code text → BFS graph expansion with cycle dedup → YAML emission. No in-memory index between invocations.
- **Hashtag recognition** — Unicode-aware regex per [ADR-002](docs/adrs/ADR-002--Hashtag-Recognition-Regex.md). Rejects URL fragments and word-adjacent `#`; accepts hyphens and underscores mid-tag.
- **Wiki-link recognition** — `[[target]]` and `[[target|anchor]]` per [ADR-001](docs/adrs/ADR-001--Wiki-Link-Recognition-Regex.md). Resolves via exact 12-digit timestamp prefix → unambiguous prefix match → unresolved.
- **Code-block exclusion** — tags and wiki-links inside fenced/indented code blocks and inline code are never recognized as structural markers.
- **Archive resolution** — precedence flag `--archive PATH` on a subcommand → `TA_DIR` env var → `archive:` key in `~/.config/ta/config.yaml`.
- **Grep fallback** — falls back to `grep -l -r` when `rg` is absent from `PATH`.
- **Symlink resolution** — archive paths that are symlinks resolve correctly before directory enumeration.
- **Agent-friendly help and error messages** — root `--help` and each subcommand's `--help` show runnable examples; error paths (missing predicates, missing refs, unresolved archive, tool-not-found) include copy-pasteable next steps.
- **Agent skills bundle** under [`docs/skills/`](docs/skills/) — three copy-pasteable skills for coding agents: `ta-search` (literal lookups), `ta-associative-recall` (fan-out recall for fuzzy queries), `ta-deep-research` (graph crawl + synthesis).
- **Design documentation** — [design spec](docs/superpowers/specs/2026-04-17-ta-cli-design.md), [implementation plan](docs/superpowers/plans/2026-04-17-ta-cli.md), and [ADRs 001–005](docs/adrs/).
- 72 tests across 16 suites, including end-to-end integration tests over a 13-note fixture archive.
