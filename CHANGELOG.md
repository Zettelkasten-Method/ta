# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **`--depth` outside 0–10 is rejected** with a validation error instead of silently clamping to 10.
- **`TACore` library target.** The pipeline now lives in a library; `ta` is a thin ArgumentParser front end. No behavior change.
- **Fewer processes per search.** The `which rg` probe is gone; `ta` runs rg and falls back to grep when rg exits 127. If neither tool is on `PATH` the error now says so.

### Fixed

- **Non-ASCII search terms never matched.** Foundation's `Process` hands argv to the child in decomposed (NFD) form, so `ta search Ständer` asked ripgrep for `Sta\u{308}nder` while note bodies are NFC. Patterns now go through stdin, in both NFC and NFD form, so either body normalization matches. A term containing a newline is rejected with a clear error.
- **`ta show` refs with special whitespace.** A ref typed with a normal space now resolves a file whose name contains a non-breaking space (or other Unicode whitespace), and NFC-typed refs resolve NFD filenames. The `ref:` line prints the on-disk name so it matches what `search` emits.

## [0.3.0] - 2026-05-28

Fixes a silent-empty-result failure for suffix-timestamped archives (`Title 202506252102.md`) and makes note ID detection configurable. Adds layered wiki-link resolution and a global `--verbose` flag so pipeline decisions are observable on stderr.

### Added

- **Configurable note ID detection.** The default pattern is now the unanchored regex `\d{12}`, a strict superset of the previous prefix-only behavior. Prefix (`202503091430 Title.md`), suffix (`Title 202506252102.md`), and mid-filename layouts all index correctly with no config required. See [ADR-006](docs/adrs/ADR-006--Note-ID-Detection.md).
- **`id_pattern` config key** in `~/.config/ta/config.yaml` for custom schemes (14-digit `YYYYMMDDHHMMSS`, alphanumeric IDs, project-specific patterns). Invalid regexes fall back to the default with a verbose-mode warning rather than crashing.
- **Layered wiki-link resolution.** `[[target]]` resolves in three tiers: exact ID → filename substring (case-insensitive, Archive-style) → unambiguous ID prefix. `[[Cognitive Distancing]]` now resolves to `Thinking About Thinking - Cognitive Distancing 202506252102.md` when the substring is unique.
- **`--verbose` global flag** on every subcommand (`search`, `tag`, `show`). Logs pipeline decisions to stderr: resolved config (archive path + id_pattern + provenance), file-scan skips with reasons, ripgrep commands and match counts, structural verification, graph expansion depth, and wiki-link resolution method. Defaults to off; stdout is unchanged.
- **ADR-006** documenting the ID-detection redesign and alternatives considered.

### Changed

- **`NoteIndex` indexes filename stems** alongside extracted IDs, enabling substring-based wiki-link resolution. All non-overlapping matches of the ID pattern in a filename become index keys (a file with two 12-digit runs is reachable via either).
- **`NoteParser` extracts the timestamp ID position-agnostically.** Title extraction no longer requires a 12-digit prefix; suffix-timestamped notes get the correct title and ID.
- **Pipeline plumbing.** `SearchPipeline`, `ShowPipeline`, and the runners accept a `ResolvedConfig` (archive + id_pattern + provenance) and an optional `Logger` so verbose mode reaches every layer.

### Internal

- New `IDPattern` type wraps a configurable regex extractor (`Sources/ta/Config/IDPattern.swift`).
- New `ResolvedConfig` bundles archive directory, ID pattern, and provenance for downstream consumers (`Sources/ta/Config/ResolvedConfig.swift`).
- New `Logger` type with injectable sink for stderr diagnostics (`Sources/ta/Logging/Logger.swift`).
- Dead `NoteIndex.extractTimestampPrefix` removed; `IDPattern.extractIDs(from:)` is the replacement.
- 33 new tests across `IDPatternTests`, `ArchiveResolverTests`, `LoggerTests`, `NoteIndexTests`, `NoteParserTests`, `SubstringResolutionTests`, `IntegrationTests`, `GraphExpanderTests`, `RipgrepRunnerTests`, `StructuralFilterTests`, and `SearchCommandTests`. The suite is now 112 tests across 19 suites.

## [0.2.0] - 2026-05-13

Search now finds matches it previously hid: text inside Markdown inline-code spans (e.g. `` `LSUIElement` ``), notes stored as `.txt`, and queries that don't match the casing of the source.

### Added

- **`.txt` notes are indexed alongside `.md`.** `NoteIndex` enumerates both extensions and the supported set is centralized at `NoteIndex.supportedExtensions`. Adding a third extension is now a one-line change. `ta show` already worked on `.txt` files via byte-for-byte body emission; this commit makes them discoverable by `ta search` and `ta tag`.
- **`ParsedNote.rawText`** carries the original source string alongside the existing `nonCodeText` projection.

### Changed

- **`ta search`'s `--word` and `--phrase` predicates now match inside inline-code spans.** Previously, terms wrapped in backticks (e.g. `` `LSUIElement` ``) were stripped before search and invisible to all predicates. Word and phrase predicates now match against the raw note text. Hashtag matching (`--tag`) still respects inline-code stripping — `#foo` inside backticks is not counted as a tag, and `[[link]]` inside backticks is not counted as a wiki link.
- **All predicates (`--tag`, `--phrase`, `--word`) are now case-insensitive.** `ta search --word lsuielement` finds `LSUIElement`; `ta search --tag macos` finds `#MacOS`. Both the ripgrep/grep candidate-selection layer and the in-process structural filter use case-insensitive matching consistently.
- **Snippets in search output** come from the raw note text, so the surrounding context shown to the user matches what they would see in the file (including any backticks).

### Internal

- `RipgrepRunner` derives its `-g`/`--include` flags from `NoteIndex.supportedExtensions` rather than hardcoding `*.md`.
- `NoteParser.titleFromFilename` uses `NSString.deletingPathExtension` instead of magic-numbered `removeLast(3|4)` branches.
- 7 new tests across `NoteIndexTests`, `RipgrepRunnerTests`, `StructuralFilterTests`, and `IntegrationTests`; the suite is now 79 tests across 16 suites.

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

[Unreleased]: https://codeberg.org/ctietze/ta/compare/0.3.0...HEAD
[0.3.0]: https://codeberg.org/ctietze/ta/releases/tag/0.3.0
[0.2.0]: https://codeberg.org/ctietze/ta/releases/tag/0.2.0
[0.1.0]: https://codeberg.org/ctietze/ta/releases/tag/0.1.0
