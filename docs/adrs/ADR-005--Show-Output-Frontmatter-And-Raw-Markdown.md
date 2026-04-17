---
title: "ADR-005: Show Output as YAML Frontmatter + Raw Markdown"
date: 2026-04-17
deciders:
  - Christian Tietze
consulted:
  - Claude Sonnet 4.5
status: accepted
related:
  - ADR-004
---

# ADR-005: Show Output as YAML Frontmatter + Raw Markdown

## Context

`zk-llm show REF...` accepts one or more NoteRef positional arguments and emits the full body of each referenced note on stdout. The output is consumed by coding agents that will pass the content into an LLM for summarization, extraction, or further reasoning.

Key constraints:

1. **Markdown bodies must pass through verbatim.** The agent's LLM is trained on raw markdown; re-encoding or escaping degrades retrieval quality. Code fences, inline code, tables, math blocks — all must render exactly as they appear on disk.
2. **Multiple refs in one invocation.** The agent issues one `zk-llm show ref1 ref2 ref3` call rather than three separate calls (reducing subprocess latency and giving the agent a single response to process). The output must be self-delimiting so the agent can split it back into per-ref chunks.
3. **Metadata per ref.** Alongside the body, the agent wants the ref, title, tags, and outgoing links — the same compact summary structure emitted by `search` (ADR-004). Having metadata and body colocated saves the agent a second query.
4. **Missing refs are not a hard error.** A batch of three refs where one is missing should still produce output for the other two, with the missing one clearly flagged. Aborting the whole invocation because one ref is gone would force the agent into per-ref calls just to isolate failures.

## Decision

Emit each ref as a **YAML frontmatter block** (delimited by `---` lines on their own) immediately followed by the **raw markdown body**. Multiple refs are concatenated.

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

### Format rules

- Each block opens with `---` on a line by itself, contains YAML, closes with `---` on a line by itself.
- The raw markdown body follows the closing `---` until the next opening `---` or end-of-stream.
- Frontmatter key order: `ref`, `title`, `tags`, `links`, then optional error fields.
- The body is streamed verbatim from the source file. No trimming, no trailing-newline normalization, no YAML string escaping.

### Missing-ref handling

When a ref doesn't resolve, emit a frontmatter-only block with an `error` field and no body:

```
---
ref: "202503091430 Missing.md"
error: not-found
---
```

Subsequent refs in the same invocation still emit normally.

### Ordering

Output order matches argv order. If the agent passes refs in a meaningful order (e.g., by relevance from a prior `search` call), that order is preserved.

### Exit code

Non-zero only if *zero* refs resolved. If at least one ref produced output (even if others were missing), exit 0.

## Alternatives Considered

### A. Pure YAML with body as block scalar

```yaml
- ref: "202503091430 Mental Models.md"
  title: "Mental Models"
  tags: [...]
  body: |
    # Mental Models

    Body of the note here...
```

**Rejected because:**

- Code blocks in the body become awkwardly double-indented under the `|` block scalar. For a note with a Python snippet, the indented Python becomes 4-space indented from the `body: |`, and the YAML spec is strict about indentation consistency — edge cases around empty lines and tabs bite.
- Content containing `---` inside the body needs no escaping in YAML block scalar form, but the visual comprehension is degraded: agents (and humans during the demo) have to mentally de-indent the entire body.
- Parsers that stream YAML often buffer the full document; with bodies of tens of KB, this adds memory pressure for no benefit.

### B. JSON with body as a string field

```json
[
  {"ref":"...","title":"...","body":"# Mental Models\n\nBody...\n"}
]
```

**Rejected because:**

- Every newline, quote, and backslash in the body requires JSON escaping. Code fences with embedded quotes produce long escape sequences that reduce readability on stdout and bloat the token count.
- LLMs consuming JSON-escaped markdown sometimes hallucinate unescaping errors or inconsistently render the content.
- YAML frontmatter is the dominant real-world convention for markdown-with-metadata (Jekyll, Hugo, Obsidian, Quartz). Agents' training data heavily covers this shape.

### C. Null-byte or other sentinel delimiter

```
<meta-json-0>\0<body-0>\0<meta-json-1>\0<body-1>\0
```

**Rejected because:**

- Not human-readable; degrades the demo.
- Null bytes don't survive shell pipelines cleanly in all contexts.
- Agents can reliably split on `---` at column 0; a more exotic delimiter offers no upside.

### D. JSONL with per-ref JSON objects

```
{"ref":"...","title":"...","body":"..."}
{"ref":"...","title":"...","body":"..."}
```

**Rejected because:** same JSON-escape pain as alternative B. Self-delimiting is the one upside, but frontmatter's `---` delimiter is equally self-delimiting while preserving verbatim markdown.

### E. One file per ref written to a temp directory

`zk-llm show` writes to `$TMPDIR/zk-llm-NNN/ref1.md, ref2.md` and prints the directory.

**Rejected because:** introduces filesystem side effects; the agent must then read those files; cleanup responsibility is ambiguous; the stdout stream is no longer the product. The whole point of a Unix tool is stdout.

## Consequences

### Positive

- **Verbatim markdown.** Zero lossy encoding. Agents consume the exact bytes the LLM is best at understanding.
- **Self-delimiting.** Agents split on `^---$` boundaries. No wrapping JSON array, no trailing-comma edge cases.
- **Convention-native.** The Jekyll/Obsidian frontmatter style is ubiquitous. Agents are already excellent at parsing it.
- **Partial success.** Missing refs don't poison the whole batch.

### Negative

- **Delimiter collision risk.** A note body that starts with `---` at column 0 (a markdown thematic break in one of its forms) could be misparsed as the start of the next frontmatter block. Accepted for the prototype:
  - Thematic breaks are conventionally written as `***` or `___` more often than `---` in practice.
  - Notes in The Archive idiom rarely open with a thematic break.
  - Agents parsing the output can apply a two-pass strategy: first scan for frontmatter-shaped blocks (starts with `---`, followed by valid YAML, ends with `---`, followed by content), falling back if a putative delimiter doesn't open a valid block.
  - If the risk materializes in practice, a future refinement: escape `---` at body column 0 to a different marker, or use a unique `---zk-llm---` sentinel. Additive change, no call-site breakage.
- **Not streaming-friendly for partial results.** We materialize each note's frontmatter before emitting its body. For 10 KB bodies this is fine; for a hypothetical 10 MB note it would be noticeable. Not a concern for the 10K-note Zettelkasten (notes are typically small).

### Neutral

- **Argv order is the output order.** Agents that want sorted output sort their argv before calling.
- **Exit code is binary-ish.** Zero if any ref resolved, non-zero if none did. This is a pragmatic compromise between "strict all-or-nothing" and "silently swallow all errors." The per-ref `error: not-found` frontmatter carries the detailed failure signal.
