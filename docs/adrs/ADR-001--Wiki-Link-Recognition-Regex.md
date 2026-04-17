---
title: "ADR-001: Wiki-Link Recognition Regex"
date: 2026-04-17
deciders:
  - Christian Tietze
consulted:
  - Claude Sonnet 4.5
status: accepted
related:
  - ADR-002
---

# ADR-001: Wiki-Link Recognition Regex

## Context

The zk-llm CLI must detect wiki-links of the forms `[[target]]` and `[[target|display text]]` so it can expand the outgoing-link graph around search hits. `swift-markdown` (our AST parser) has no native wiki-link support — wiki-links appear to it as `[`, `[`, `text`, `]`, `]` inline nodes (or occasionally as malformed link syntax, since `[[...]]` is not CommonMark).

The Archive v1 has been using a regex-based approach for this same syntax since the project's inception. The regex has been battle-tested across user archives that include Unicode characters, anchor text with pipe separators, and miscellaneous false-positive candidates (math expressions with double brackets, array syntax, etc.).

### Constraints

1. **Structural context required.** The regex must be applied only to non-code text — wiki-link syntax inside fenced code blocks or inline code spans is not a link and must not be extracted. The AST walk (see §7 of the design spec) is responsible for supplying only the safe text; the regex does not need to re-solve the code-block problem.
2. **Single-line matches only.** Wiki-links do not span newlines in practice. Multi-line matches create pathological behavior on malformed input (e.g., an unclosed `[[` at end of paragraph followed by hundreds of lines of prose).
3. **Anchor text is optional.** `[[target|display]]` must match, with group 1 being just `target`. The display text is discarded before ID resolution.
4. **Greedy matching is wrong.** `[[a]] and [[b]]` must produce two matches, not one `[[a]] and [[b]]`. The target portion must not contain `]` characters.

## Decision

We adopt the regex:

```
\[\[([^\]|\n]+)(?:\|[^\]\n]+)?\]\]
```

Applied to the non-code text buffer produced by the Stage 2 AST walk. Capture group 1 is the resolved target; anchor text after `|` is matched but discarded.

### Rationale

- `[^\]|\n]+` for the target: rejects `]` (prevents greedy over-capture) and `\n` (single-line only). Allows `|` only outside the target portion (i.e. after the target starts, the `|` begins the anchor-text portion).
- `(?:\|[^\]\n]+)?` for optional anchor text: matches `|` followed by any characters except `]` or newline. The anchor text is matched but not captured.
- `\[\[` and `\]\]` are literal; the double brackets are the fixed marker of the syntax.
- No Unicode flag needed — the negated character classes are already Unicode-safe in Swift's regex engine.

### Evidence of behavior on edge cases

- `[[202503091430]]` → group 1 = `202503091430`. Matches.
- `[[202503091430|some title]]` → group 1 = `202503091430`. Anchor text discarded.
- `[[foo]] and [[bar]]` → two matches. Target 1 = `foo`, target 2 = `bar`.
- `[[a\nb]]` → no match. Newline rejected.
- `[[unclosed` → no match.
- `[[a]bc]]` → matches with target = `a`. Trailing `bc]]` ignored.
- `` `[[literal]]` `` inside inline code → not in the non-code buffer; not seen by the regex.

## Alternatives Considered

### A. Custom CommonMark extension via swift-cmark

Register a syntax extension that teaches cmark to parse `[[...]]` as a first-class inline node.

**Rejected because:** cmark extensions are C-level plumbing, require forking or patching, and couple us to a CMake build path — exactly the problem we set out to avoid by choosing swift-markdown over lib.multimarkdown6. Zero benefit for the prototype.

### B. Parser combinator or hand-written state machine

Write a mini-parser that tracks bracket depth, escape sequences, and delimiters explicitly.

**Rejected because:** equivalent expressiveness to the regex, more code, no measurable perf win at 10K notes (the AST walk dominates the wall clock). The regex is smaller and more readable.

### C. User-configurable wiki-link pattern

Let the user define their own syntax (e.g., `{{link}}` or `@link`).

**Rejected because:** the zk-llm CLI is a prototype for a specific Zettelkasten flavor (The Archive's). Users on other flavors can fork. Premature generality.

### D. Greedy `.+?` target

Use `\[\[(.+?)\]\]` with `DOTALL` disabled.

**Rejected because:** `.` in Swift regex defaults to non-newline, which is fine, but `.+?` allows `|` inside the target, which means `[[a|b]]` would capture `a|b` as the target instead of recognizing `a` as target and `b` as anchor text.

## Consequences

### Positive

- **Self-contained.** No external syntax-extension infrastructure, no parser combinator library, no cmark fork.
- **Direct port from v1.** The regex is the same shape v1 has been using in production; edge cases already discovered and survived.
- **Fast.** NSRegularExpression on a per-paragraph text buffer is O(n) in buffer size. At typical note sizes (1–10 KB of non-code text) this is microseconds.

### Negative

- **Escape-sequence blind.** `\[\[literal\]\]` in markdown is not really a wiki-link; we don't currently handle the escaped form. Acceptable — users don't typically write this.
- **No fuzzy recovery.** A malformed `[[a]` (single bracket close) produces no match, not a "did you mean" suggestion. Prototype scope.

### Neutral

- The regex is applied per-block (via the non-code text buffer), so per-block match position is known. This is what feeds the snippet-extraction window (see design spec §6).
