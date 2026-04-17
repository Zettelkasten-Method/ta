---
name: ta-deep-research
description: Use when the user wants to explore, trace, map, or synthesize their thinking across multiple notes on a topic — "how have I thought about X?", "trace Y through my notes", "map everything around Z", "give me a summary of what my Zettelkasten says about [topic]". For single lookups use ta-search; for vibe queries use ta-associative-recall.
---

# Deep research over a Zettelkasten

This skill is read-heavy. It uses `ta`'s graph-expansion and `show` commands to crawl the user's thought network around a topic, read hub notes selectively, extract connecting concepts, and synthesize a narrative summary with citations.

## The workflow

```
Seed (ref / tag / concept)
  → expand graph with --depth 2 or 3
  → select 3–5 hub notes to show (don't read everything)
  → extract concepts from bodies
  → iterate up to 3 times on new concepts
  → synthesize with ref citations
```

## Step 1 — Seed

Three seed shapes, in rough order of preference:

**Known ref** — user named one, or a previous step surfaced one:

```bash
ta show "202503091430 Mental Models.md"
```

Read the body. Note outgoing `[[wiki-links]]` and `#tags`.

**Known tag** — user said "trace #learning":

```bash
ta tag learning --depth 2
```

**Concept only** — user described a topic without naming a ref or tag. Delegate to `ta-associative-recall` first to surface 1–3 seed refs, then continue here.

## Step 2 — Expand the graph

From each seed, expand the neighborhood:

```bash
ta search --tag <primary-tag> --depth 2
```

Depth guidance:

- `--depth 1` — immediate neighbors. Use when the graph is dense.
- `--depth 2` — default for exploration. Usually enough.
- `--depth 3` — only when the graph is sparse. Above 3, signal-to-noise collapses.

Parse the YAML. Two shapes matter:

- **Direct hits** (`depth: 0`) — the core of the topic.
- **Expansion nodes** (`depth > 0` with `via:`) — the surrounding thought-graph. The `via:` field is the chain the walker followed; reading it shows the path the user's own links created between concepts.

## Step 3 — Read selectively

Do not `show` every result. Pick 3–5:

- **Hubs** — refs that appear in multiple `links:` arrays across your result set. The user links to them often, so they're likely synthesis points.
- **The seed itself** — always read it.
- **Synthesis titles** — titles like "Rules for ...", "Summary of ...", "Index of ..." tend to be aggregation notes.

```bash
ta show "<ref1>" "<ref2>" "<ref3>"
```

Scan the bodies for:

- Concepts named but not tagged — new pivot candidates.
- Quoted sources or external references.
- Patterns in the user's own voice ("I think X is really about Y") — synthesis gold.

## Step 4 — Extract and iterate

From what you read, extract 1–3 candidate concepts that:

- Appear across multiple notes.
- Weren't in your original seed's tags.
- Suggest a connection you hadn't probed.

Run a new expansion on one of them. Maintain a visited-refs set — don't re-read.

Cap at 3 iterations. If the user wants deeper, they'll say so.

## Step 5 — Synthesize

Present a narrative, not a list:

```
Your thinking on <topic> clusters into three themes:

1. <Theme 1>. You develop this in:
   - "202503091430 Mental Models.md" — [one-line hook from the body]
   - "202503091431 Second Order Thinking.md" — [hook]

2. <Theme 2>. Anchored by:
   - "201105201217 …" — [hook]

3. <Theme 3>. A later note ties it to <connecting concept>:
   - "202211261540 …" — [hook]

The thread connecting all three seems to be <concept you noticed across them>.
```

Include full refs (the user can `ta show` them directly). Never paraphrase so aggressively that the user loses the trail back to their own words.

## Graph-reading heuristics

- A ref with many incoming links (appears in many `links:` arrays) is a **hub**. Hubs are where synthesis lives.
- A ref with many outgoing links (long `links:` array) is an **index** or overview. Read it early.
- A long `via:` chain (depth 2 or 3) often surfaces surprising connections. Research gold.
- `unresolvedLinkText` in a `ParsedNote` or `error: not-found` from `show` means the user wrote a wiki-link that doesn't resolve — possibly a half-finished thought worth noting.

## Budget warning

If the initial search returns more than 20 direct hits, the topic is broad. Tell the user before reading:

> "Your archive has 34 direct hits on that topic — too many to read deeply. Want me to narrow with an additional tag, or pick one sub-theme to go deep on?"

Use `AskUserQuestion` for the narrowing (plain-text fallback on non-Claude agents).

## Don't

- Don't read more than 5–7 notes per iteration. Synthesis fails when the context fills with full bodies.
- Don't push `--depth` above 3.
- Don't skip the synthesis step. A bare ref list isn't research — it's just search.
- Don't hallucinate connections. If you cite "the thread connecting all three", the thread should be literally visible in the bodies you read.
