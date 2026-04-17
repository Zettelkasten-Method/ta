---
title: "ADR-002: Hashtag Recognition Regex"
date: 2026-04-17
deciders:
  - Christian Tietze
consulted:
  - Claude Sonnet 4.5
status: accepted
related:
  - ADR-001
---

# ADR-002: Hashtag Recognition Regex

## Context

The ta CLI must detect `#hashtag` tokens in note bodies so it can emit the `tags:` leaf annotation on each YAML search result and verify `--tag foo` predicates structurally (not just via raw-text `rg` hits).

The Archive v1 has treated `#hashtag` as a clustering primitive since its inception. The recognition rule there distinguishes between:

- **Real hashtags**: `#mental-models`, `#ai`, `#zettelkasten-2026` — preceded by whitespace, punctuation, or start-of-line; containing letters, digits, underscore, or dash; terminated by a non-word boundary.
- **Headings**: `# Mental Models` — a `#` followed by a space at column 0. The space breaks hashtag recognition. These are markdown structure, not tags.
- **URL fragments**: `https://example.com/page#section` — preceded by a word character (`e`), so not a hashtag.
- **Code**: `# This is a Python comment` — inside fenced code blocks. Handled at the AST level (ADR-001 context applies here too); the regex is only applied to non-code text.

### Constraints

1. **Word-boundary preceding.** `#` must be at start-of-string or preceded by a non-word character. This rejects URL fragments and inline `word#tag` patterns.
2. **Markdown headings exclusion.** A literal `# ` (hash + space) at the start of a heading block is already filtered by the AST walk: `Heading` nodes contribute their *content* text (after the `#` markers are consumed by the parser) but not the `#` markers themselves. The regex does not need special-case logic for headings.
3. **Unicode letters acceptable.** German, Japanese, etc. hashtags must work: `#Ernährung`, `#日本語`. Latin-only `[a-zA-Z]` is wrong.
4. **Hyphen and underscore allowed inside.** `#mental-models`, `#well_known` are valid tags.
5. **Pure-numeric tags allowed.** `#2026` is a legal tag (year tag). Not rejected.
6. **Trailing punctuation excluded.** `See #foo.` should yield tag `foo`, not `foo.`. The trailing `.` is not a word character and must not be swept into the match.

## Decision

We adopt the regex:

```
(?<=^|[^\p{L}\p{N}_])#([\p{L}\p{N}_-]+)
```

Applied to the non-code text buffer produced by the Stage 2 AST walk. Capture group 1 is the tag name (the leading `#` is stripped by the regex).

### Rationale

- `(?<=^|[^\p{L}\p{N}_])` is a lookbehind asserting that `#` is at start-of-string or preceded by a non-word character. This rejects `example.com#section` (where `e` is `\p{L}`).
- `#` is a literal match.
- `[\p{L}\p{N}_-]+` matches one or more word characters (Unicode letter or number), underscore, or hyphen. Dash (`-`) is placed at the end of the class to avoid ambiguity with range syntax.
- Because `-` is non-word and `.` is non-word, they are both naturally excluded from the match, so `See #foo.` yields just `foo`.
- No explicit trailing `\b` needed: the `+` quantifier is greedy but the character class itself excludes all non-tag characters.

### Evidence of behavior on edge cases

- `See #foo, #bar, and #baz.` → three matches: `foo`, `bar`, `baz`.
- `#2026` → match: `2026`.
- `#Ernährung` → match: `Ernährung`.
- `https://example.com/page#section` → no match (preceded by `e`).
- `word#tag` → no match (preceded by `d`).
- `Multiple##hashes` → no match (preceded by `#` but `#` is non-word, so `(?<=[^\p{L}\p{N}_])` succeeds for the second `#`, and the tag captured is the text after — wait, the second `#` is preceded by `#`, which is non-word, so it matches; capture = whatever follows). This is an edge case. In practice v1 accepts `##heading-like` as producing a tag `heading-like`. We accept the same behavior.
- Heading `# Mental Models` → the AST strips the `#` marker before the text reaches our buffer. The text `"Mental Models"` has no `#`, so no match. Correct.
- Code block containing `#foo` → not in the non-code buffer, so not seen. Correct (per AST walk in ADR-001 context).

## Alternatives Considered

### A. Simple `#\w+` regex

Use `\w` to match word characters.

**Rejected because:** `\w` in Swift's regex engine is ASCII-only by default. `#Ernährung` would match `#Ern` and stop. Unicode property classes (`\p{L}`, `\p{N}`) are required for correctness.

### B. Require leading space

Match `(^|\s)#[\p{L}\p{N}_-]+`.

**Rejected because:** too strict. `(#foo)` in parentheses, `,#bar` after a comma, `[#baz]` inside brackets — all are legitimate tag contexts in practice. The negated word-char lookbehind correctly accepts these.

### C. Tokenize first, then classify

Split the buffer on whitespace and check each token for a `#` prefix.

**Rejected because:** breaks `See #foo, #bar.` because the tokens become `See`, `#foo,`, `#bar.`. Stripping trailing punctuation per-token is extra work that the regex handles inline.

### D. User-configurable tag character set

Let the user declare what characters can appear in a tag.

**Rejected because:** premature flexibility. v1 has shipped with a fixed character set for years and users have adapted. Prototype scope.

## Consequences

### Positive

- **Direct port from v1.** Same shape, same edge-case behavior, same false-positive rejection.
- **Unicode-correct.** Works for non-English tags without special casing.
- **Composable with AST walk.** Headings, code blocks, and inline code are handled at the AST layer (ADR-001 context); the regex only needs to worry about the cases that actually reach it.
- **Fast.** Per-buffer O(n) match via NSRegularExpression.

### Negative

- **Lookbehind dependency.** Swift's modern `Regex<>` type supports lookbehinds in the current platform version; older Swift runtimes or downgraded toolchains might not. Acceptable — we require Swift 6 per §8 of the design spec.
- **Edge case `##tag` produces a tag.** Arguably a user typo. We accept v1's behavior rather than add complexity to reject it.

### Neutral

- The capture group returns the tag name *without* the leading `#`. Consumers (the YAML emitter, the tag-predicate verifier) already expect this shape.
