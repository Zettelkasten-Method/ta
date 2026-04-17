---
name: ta-search
description: Use when the user asks to find, search, or look up a note in their Zettelkasten with specific named terms — "find my note about X", "search for Y in my notes", "list everything tagged Z". For fuzzy or vibe queries, use ta-associative-recall instead. For exploring a topic across many notes, use ta-deep-research.
---

# Searching a Zettelkasten with ta

`ta` is a literal, ripgrep-backed retrieval CLI over the user's Zettelkasten archive. It does not do semantic similarity — what you type is what it searches. For fuzzy matches, delegate to `ta-associative-recall`.

## The three subcommands

- `ta search` — AND-combined predicates, YAML list output.
- `ta tag NAME` — shortcut for `search --tag NAME`.
- `ta show REF [REF ...]` — print frontmatter + raw body per ref.

If no archive is configured, the CLI tells you how: pass `--archive PATH` on the subcommand, set `TA_DIR`, or write `archive: /path` to `~/.config/ta/config.yaml`.

## Predicates

All repeatable. All AND-combined.

- `--tag NAME` — requires `#NAME` in non-code text. Use for user-curated vocabulary. Supply the name without the leading `#`.
- `--phrase "TEXT"` — requires the literal string in non-code text. Case-sensitive substring.
- `--word WORD` — requires whole-word match. Better than `--phrase` for a single distinctive term because it respects word boundaries.
- Positional argument — treated as `--phrase`.

Depth: `--depth N` expands results along wiki-link edges by N hops (default 3, hard cap 10). Use `--depth 0` when you want direct hits only.

## Reading the YAML output

Each entry is a `- ref: ...` block with:

- `ref` — the note's full filename (with `.md`). Pass this to `show`.
- `title` — filename stem.
- `snippet` — ~120-char window around the first hit (direct hits only).
- `tags` — hashtag names in document order.
- `links` — resolved outgoing wiki-links (full filenames with `.md`).
- `depth` — 0 for direct hits, >0 for graph expansion.
- `via` — parent ref for expansion nodes; `null` for direct hits.

Empty result set is the literal `[]` on a single line.

## Choosing the right query

| User intent | Recommended query |
|---|---|
| Notes with a specific hashtag | `ta tag NAME` |
| Notes with two hashtags at once | `ta search --tag A --tag B` |
| Notes mentioning a distinctive single word | `ta search --word TERM` |
| Notes containing a specific phrase | `ta search --phrase "TEXT"` or `ta search "TEXT"` |
| Notes about a topic without knowing exact terms | Delegate to `ta-associative-recall`. |
| Explore around a starting note | Delegate to `ta-deep-research`. |

## Reducing noise

- Start with `--depth 0` when you want a focused result set.
- Prefer `--tag` over `--phrase` when the user named a known hashtag — tags are user-curated signal.
- Combine predicates (AND) to narrow: `ta search --tag learning --word inversion`.
- If zero results, try widening: drop a predicate, or switch `--phrase "second-order"` → `--word second`.

## Showing a note

```bash
ta show "202503091430 Mental Models.md"
```

Multiple refs concatenate. Exit code 1 if no refs resolve.

Refs are the full filenames from `search` / `tag` output's `ref:` field. They include `.md` and may contain spaces — always quote them.

## Don't

- Don't invent refs. Always get them from `search` / `tag` output first.
- Don't strip `.md` from refs — `show` expects the full filename.
- Don't pass `#` as part of `--tag` — the leading `#` is implied.
- Don't use this skill for fuzzy recall ("that thing I wrote about..."). Delegate to `ta-associative-recall`.
