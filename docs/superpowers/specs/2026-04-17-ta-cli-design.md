---
title: "ta CLI — Design"
date: 2026-04-17
status: draft
---

# ta CLI — Design

A command-line retrieval tool over a Zettelkasten archive, intended for consumption by coding agents. Prototype quality, one-day implementation target.

## 1. Purpose & Scope

### Purpose

Expose a user's Zettelkasten (10,000 markdown notes, 12-digit timestamp filenames) to coding agents as a retrieval API. Agents compose search predicates, receive small YAML summaries with a bounded neighborhood graph around each hit, and retrieve full note bodies on demand.

The core flow: agent asks a topic question, drives retrieval through the CLI, narrows candidates using structural awareness (not raw text), follows wiki-link edges to relevant neighbors, then reads the bodies it deems worth reading.

### Scope

- Fast full-text filtering via `rg` (with `grep` fallback).
- Structural filtering via `swift-markdown` AST walk plus v1-style regexes, so that `#hashtag` and `[[wikilink]]` matches inside fenced or inline code blocks are excluded.
- Graph expansion around each hit (wiki-link edges only), depth-capped.
- Full note body retrieval by NoteRef (filename).
- Output shaped for agent consumption: YAML for `search`/`tag`, YAML-frontmatter + raw markdown for `show`.

### Not in scope

- No in-memory index or persistent cache between invocations. Every call is cold-start.
- No Boolean query evaluator (`SearchExpressionParser` requires a full index — deferred).
- No filename schemes beyond 12-digit timestamp prefix (ADR-010 enumerates others; deferred).
- No reverse/backlink queries (`who links to X?`). Deferred.
- No tag-membership edges in the graph. Tags are leaf annotations only; `ta tag` is the explicit path.
- No writing or editing notes.
- No fuzzy matching, no `OR`/`NOT` operators. Agents synthesize these via multiple calls and set operations.
- No daemonized mode, no cross-platform distribution, no signing, no Homebrew formula. Hand-built binary executed locally.
- No integration with The Archive v1 or v2 codebases at runtime. Some concepts (NoteRef, ID prefix resolution) are borrowed from the v2 specs.

## 2. Audience

Primary consumer: a coding agent with skills that know how to invoke `ta` and parse its output. Secondary consumer: the developer demoing the tool.

Consequence: output is optimized for agent parsing and low token cost, not for human eyeballing. YAML over tables, flat lists over nested trees, bounded payloads.

## 3. Commands

Three subcommands. All write to stdout; errors go to stderr with a non-zero exit code.

The predicate surface (flag-based, AND-combined, repeatable) is specified in ADR-003. Output formats are specified in ADR-004 (search/tag) and ADR-005 (show).

### `ta search`

```
ta search [--tag TAG]... [--phrase STR]... [--word WORD]...
              [--depth N] [POSITIONAL_PHRASE]
```

Finds notes matching all predicates (AND), expands the outgoing wiki-link graph around each direct hit to `--depth` hops, emits a flat YAML list of nodes.

- `--tag TAG` — repeatable. Note must carry `#TAG` in a non-code block.
- `--phrase STR` — repeatable. Note must contain `STR` as a literal substring in a non-code block (or heading).
- `--word WORD` — repeatable. Note must contain `WORD` as a whole word in a non-code block (or heading).
- `--depth N` — graph-expansion depth. Default `3`. Hard cap `10`. `0` disables expansion (direct hits only).
- `POSITIONAL_PHRASE` — optional bare positional argument, treated as an implicit `--phrase`.

All predicates are AND-combined. Zero predicates is an error (we require at least one).

### `ta tag`

```
ta tag TAGNAME [--depth N]
```

Convenience wrapper. Equivalent to `ta search --tag TAGNAME [--depth N]`. `--depth` default is `3`, hard cap `10`, matching `search`.

### `ta show`

```
ta show REF...
```

Accepts one or more NoteRef (filename) positional arguments. Emits YAML-frontmatter + raw markdown body per ref, in argv order. Missing refs produce a frontmatter block with `error: not-found` and no body.

## 4. Pipeline Architecture

Each `search` invocation runs four stages sequentially. No state is kept across invocations.

```
┌───────────────────┐
│ Predicate flags   │ --tag, --phrase, --word (all AND'd)
└─────────┬─────────┘
          ▼
┌───────────────────┐  One rg invocation per predicate.
│ Stage 1:          │  Tags via `rg -l '#tag\b' .`, phrases
│ Fast text filter  │  via `rg -l -F STR .`, words via
│ (rg; grep fall-   │  `rg -l -w -F WORD .`. Intersect file
│  back)            │  lists -> candidate set.
└─────────┬─────────┘
          ▼
┌───────────────────┐  For each candidate file:
│ Stage 2:          │    1. Read + parse with swift-markdown.
│ Structural        │    2. Walk AST, collect non-code text
│ verification      │       (paragraph, list item, blockquote,
│ (swift-markdown + │       heading); skip CodeBlock and
│  v1 regex)        │       InlineCode.
│                   │    3. Run hashtag regex + wiki-link regex
│                   │       over the non-code text.
│                   │    4. Keep the file iff every predicate
│                   │       is still satisfied structurally
│                   │       (e.g. --tag foo requires a real
│                   │       #foo in a non-code block).
└─────────┬─────────┘
          ▼
┌───────────────────┐  For each verified hit:
│ Stage 3:          │    - Resolve outgoing wiki-links to
│ Graph expansion   │      NoteRefs (exact ID -> prefix ->
│ (wiki-link edges  │      skip).
│  only, BFS)       │    - BFS up to --depth, visited-set dedup,
│                   │      record shortest path -> (depth, via).
│                   │    - Parse reached notes only enough to
│                   │      extract outgoing links + tags.
└─────────┬─────────┘
          ▼
┌───────────────────┐  Flat YAML list:
│ Stage 4:          │    - Direct hits first (rg file order).
│ Output            │    - Expansion nodes after, BFS visit
│                   │      order.
└───────────────────┘
```

### Ripgrep runner (Stage 1)

- Launch one `rg -l` subprocess per predicate, passing the archive path.
- Parse stdout line-by-line into `Set<String>` of absolute file paths.
- Intersect all sets.
- If `rg` is not on `$PATH`, fall back to `grep -l -r` with equivalent flags (`-F` literal, `-w` word-boundary). Emit a single stderr note.
- Zero candidates short-circuits the pipeline with an empty YAML list.

### Structural verifier (Stage 2)

- For each candidate, read the file and parse with `swift-markdown`.
- Walk the AST, building a "surviving text" buffer that contains only text inside non-code block types: `Paragraph`, `Heading`, `ListItem`, `BlockQuote`, `Emphasis`, `Strong`, `Link` (visible text), etc. Skip `CodeBlock` and `InlineCode`.
- Apply v1 regexes (see §7) to the surviving text to extract hashtags and wiki-links.
- Apply predicate verification: `--tag foo` requires `#foo` in the hashtag set; `--phrase`/`--word` requires the literal to appear somewhere in the surviving text.
- Notes that survive verification become `ParsedNote` instances (the parse results are cached in-memory for Stage 3).

### Graph expander (Stage 3)

- Input: list of verified direct hits (depth 0).
- Build a lightweight `NoteIndex` on demand by enumerating the archive directory once and extracting 12-digit prefixes from filenames. No content is parsed during index construction. At 10K notes this is sub-millisecond work.
- BFS: queue starts with direct hits at depth 0. Pop, resolve outgoing wiki-links using `NoteIndex` (exact 12-digit match, then unambiguous prefix match, then skip), enqueue unseen targets at `depth+1` if `depth+1 <= --depth`.
- Resolved targets that weren't already parsed are parsed on demand (markdown AST + tags + links). Parse results are cached for the duration of the invocation to avoid re-parsing when a node is reached via multiple paths.
- Visited-set keyed by `NoteRef.filename` ensures each node appears once; the first reach wins (BFS guarantees shortest path).
- `via` records the parent on that first-reach path.

### YAML emitter (Stage 4)

See §6 for the wire format.

## 5. Data Model

```swift
struct NoteRef: Hashable {
    let filename: String   // full filename incl .md, no leading path
}

struct ParsedNote {
    let ref: NoteRef
    let title: String              // filename stem with 12-digit prefix + separator stripped
    let timestampID: String        // the 12-digit prefix, e.g. "202503091430"
    let outgoingLinks: [NoteRef]   // resolved wiki-link targets, in document order, deduped
    let unresolvedLinkText: [String]
    let tags: [String]             // leading "#" stripped, deduped, document order preserved
    let nonCodeText: String        // concatenated non-code text from AST walk; used for
                                   // predicate verification and snippet extraction.
}

// Snippet extraction is NOT a property of ParsedNote. The "first hit" offset
// depends on which predicate we're matching against, which is a search-pass
// concern. StructuralFilter computes the offset at use-site by searching
// `nonCodeText` for the predicate's needle and derives the snippet from it.
//
// `show` does NOT use ParsedNote for the body. It streams the raw file
// contents verbatim to stdout; a lightweight metadata parse (title, tags,
// links) populates the frontmatter.

struct SearchHit {
    let node: ParsedNote
    let depth: Int        // 0 = direct hit, 1...cap = reached via expansion
    let via: NoteRef?     // parent on shortest path; nil when depth == 0
    let snippet: String?  // only populated when depth == 0
}

struct NoteIndex {
    // Built once per invocation by dir-enumerating the archive and extracting
    // 12-digit prefixes. Content is not read.
    let byTimestampID: [String: [NoteRef]]   // collision-safe
    let sortedTimestampIDs: [String]         // for binary-search prefix match
}
```

### Wiki-link resolution

Mirrors ADR-010 resolution cascade, truncated:

1. Exact 12-digit match against `byTimestampID`. Unambiguous (single candidate) resolves.
2. Unambiguous prefix match against `sortedTimestampIDs`. If a prefix yields exactly one candidate across all IDs starting with it, resolves.
3. Otherwise skip. The unresolved link text is preserved in `unresolvedLinkText` for debugging.

Title-based resolution is deliberately omitted per ADR-010 rationale (titles are not unique).

## 6. Output Formats

Rationale and alternatives for both output formats are captured in ADR-004 (search/tag) and ADR-005 (show).

### `search` and `tag`: YAML list

```yaml
- ref: "202503091430 Mental Models.md"
  title: "Mental Models"
  snippet: "...second-order thinking is about tracing the chain..."
  tags: [learning, thinking]
  links: ["202504151200 Second Order.md", "202505100900 Inversion.md"]
  depth: 0
  via: null
- ref: "202504151200 Second Order.md"
  title: "Second Order"
  tags: [thinking]
  links: ["202506010800 Compounding.md"]
  depth: 1
  via: "202503091430 Mental Models.md"
```

- Flat list, not a nested tree. Each node appears once; `depth` is shortest-path distance from the nearest direct hit; `via` is the parent on that path.
- `snippet` is only emitted when `depth == 0`. It is ~120 characters of non-code text centered on the first predicate hit recorded during structural verification. For tag-only hits, the "hit" position is the first occurrence of the matched hashtag in the non-code text buffer. If the hit is near the start or end of the buffer, the window is clamped and shortened rather than padded.
- `tags` are hashtag names without the leading `#`, in document order, deduped.
- `links` are the node's resolved outgoing wiki-link NoteRefs, in document order, deduped. Unresolved links are not emitted in `links` (they live in the data model but are suppressed in output to keep the YAML lean).
- Empty result: output is the literal `[]` on a single line.

### `show`: YAML-frontmatter + raw markdown

```
---
ref: "202503091430 Mental Models.md"
title: "Mental Models"
tags: [learning, thinking]
links: ["202504151200 Second Order.md"]
---
# Mental Models

Body of the note here, verbatim markdown, including any code fences.
---
ref: "202504151200 Second Order.md"
title: "Second Order"
tags: [thinking]
links: []
---
# Second Order

Next note's body...
```

- Frontmatter blocks are delimited by `---` lines on their own. Each block opens with `---`, contains YAML, closes with `---`, then the raw body follows until the next `---` opener.
- Raw markdown bodies pass through verbatim. No YAML string escaping. The delimiter collision risk (a body starting with `---` at column 0) is accepted for the prototype; markdown thematic breaks are conventionally written as `***` or `___` more often than `---`, and agents can parse frontmatter boundaries robustly.
- Missing refs emit a frontmatter block with no body, in this shape:

  ```
  ---
  ref: "202503091430 Missing.md"
  error: not-found
  ---
  ```

## 7. Structural Filter Details

Wiki-link and hashtag recognition rules, including alternative considered and rejected, are captured in ADR-001 (wiki-links) and ADR-002 (hashtags).

### AST walk

The non-code text buffer is built by walking the `swift-markdown` AST and including text from the following node types:

- `Paragraph`, `Heading`, `BlockQuote`, `ListItem`, `Table.Cell`
- Inline formatting wrappers: `Emphasis`, `Strong`, `Strikethrough`, `Link` (visible text)
- `Text` and `Space` inline nodes

Excluded:

- `CodeBlock` (fenced and indented)
- `InlineCode`
- HTML blocks (`HTMLBlock`, `InlineHTML`) — treat as escaped for the prototype

### Regexes (v1 port)

- **Hashtag**: `#[\p{L}\p{N}_-]+` with word-boundary anchoring at both ends. `#123` counts; `abc#foo` does not.
- **Wiki-link**: `\[\[([^\]|\n]+)(?:\|[^\]\n]+)?\]\]`. Group 1 is the target text. Anchor text after `|` is discarded before resolution. Newlines inside a wiki-link are rejected.

### Predicate verification

- `--tag foo` passes iff `foo` appears in the extracted tag set (structural match, not substring).
- `--phrase STR` passes iff `STR` appears as a literal substring of the non-code text buffer.
- `--word WORD` passes iff `WORD` appears with word boundaries in the non-code text buffer.

Candidates that fail any predicate after the structural pass are dropped, even if `rg` matched them in Stage 1.

## 8. Stack & Dependencies

- Swift 6, SwiftPM executable product `ta`, single target.
- SwiftPM dependencies:
  - `apple/swift-argument-parser`
  - `apple/swift-markdown`
  - `jpsim/Yams`
- Runtime: `rg` on `$PATH` preferred; `grep -l -r` fallback.
- Build: `swift build -c release` produces `./.build/release/ta`.
- No daemon, no bundled index, no inter-invocation cache.

## 9. Configuration

Archive location resolved in order:

1. `--archive PATH` CLI flag.
2. `TA_DIR` environment variable.
3. `~/.config/ta/config.yaml` with a single key: `archive: /absolute/path`.

If none resolve, exit non-zero with a stderr message pointing at the config file path.

## 10. Project Layout

```
ta/
├── Package.swift
├── Sources/
│   └── ta/
│       ├── main.swift                  # ArgumentParser root command
│       ├── Commands/
│       │   ├── SearchCommand.swift
│       │   ├── ShowCommand.swift
│       │   └── TagCommand.swift
│       ├── Pipeline/
│       │   ├── RipgrepRunner.swift     # + grep fallback
│       │   ├── StructuralFilter.swift  # swift-markdown walk + regex
│       │   ├── GraphExpander.swift     # BFS, depth cap, dedup
│       │   └── NoteIndex.swift         # prefix-match resolver
│       ├── Model/
│       │   ├── NoteRef.swift
│       │   ├── ParsedNote.swift
│       │   └── SearchHit.swift
│       ├── Parsing/
│       │   ├── WikiLinkRegex.swift
│       │   ├── HashtagRegex.swift
│       │   └── NoteParser.swift        # swift-markdown → ParsedNote
│       ├── Output/
│       │   ├── SearchYAMLEmitter.swift
│       │   └── ShowEmitter.swift
│       └── Config/
│           └── ArchiveResolver.swift
└── Tests/
    └── taTests/
        ├── Fixtures/
        │   └── sample-archive/         # ~20 notes, hand-crafted
        └── <unit test files>
```

## 11. Testing

- Unit tests per module, using a small hand-crafted fixture archive (~20 notes) under `Tests/Fixtures/sample-archive/`.
- Coverage targets:
  - Hashtag regex edge cases (leading punctuation, Unicode letters, word-boundary behavior, `#` in URLs).
  - Wiki-link resolution: exact 12-digit match, unambiguous prefix, ambiguous prefix (drops), missing.
  - AST walk: hashtags and wiki-links inside fenced code blocks and inline code are NOT extracted; inside emphasis and links they ARE.
  - BFS expansion: depth cap respected, cycles deduped, multiple-path nodes appear once with shortest depth and correct `via`.
- One integration test: drive `ta search --tag foo` against the fixture, snapshot the YAML output.
- No benchmark suite for the demo. Performance is validated by running against the user's real 10K-note archive during the demo itself.

## 12. Deliverable for the Demo

1. `swift build -c release` produces a binary.
2. The binary runs against the user's real archive via `TA_DIR`.
3. A small agent skill (out of scope for this spec but in scope for the demo choreography) invokes `ta search`, reads YAML, selects refs, invokes `ta show`, summarizes findings.
4. Perf bar: a typical `ta search --tag foo --phrase "bar" --depth 3` completes in well under 2 seconds on a 10K-note archive on Apple Silicon. No hard SLA; "demo feels snappy" is the test.

## 13. Open Items Explicitly Deferred

| Item | Why deferred |
|------|---|
| `SearchExpressionParser` Boolean evaluation | Requires full in-memory index; evaluator can't run incrementally over a streaming candidate set. |
| Reverse/backlink queries | Requires a pre-built reverse index; out of one-day scope. |
| Tag-expansion edges in the graph | Explodes payload; `ta tag` covers the use case. |
| Multiple filename schemes (Folgezettel, timestamp-to-second, title-only) | ADR-010 defines these; prototype hardcodes 12-digit timestamp. |
| Fuzzy matching | Needs trigram index or similar. Out of scope. |
| Persistent cache between invocations | Daemonization territory; out of scope. |
| Distribution (signing, Homebrew) | Local build only. |

## 14. References

### ta ADRs

- ADR-001 — Wiki-Link Recognition Regex.
- ADR-002 — Hashtag Recognition Regex.
- ADR-003 — CLI Predicate Surface — Flag-Based AND Composition.
- ADR-004 — Search Output as Flat YAML with Depth and Via Metadata.
- ADR-005 — Show Output as YAML Frontmatter + Raw Markdown.

### The Archive v2 references

- ADR-010 (Archive v2) — Note Identity Parsing via Closed Scheme Types (filename-as-identity, prefix resolution cascade).
- ADR-013 (Archive v2) — Markdown-Only File Format.
- ADR-020 (Archive v2) — Filesystem-Filename Identity (NoteRef as filename).
- SDD-Note-Discovery (Archive v2) — search pipeline and result shape.
- SDD-Tag-Index (Archive v2) — tag extraction semantics.

### Third-party dependencies

- `apple/swift-markdown` — https://github.com/apple/swift-markdown
- `apple/swift-argument-parser` — https://github.com/apple/swift-argument-parser
- `jpsim/Yams` — https://github.com/jpsim/Yams
- `BurntSushi/ripgrep` — https://github.com/BurntSushi/ripgrep
