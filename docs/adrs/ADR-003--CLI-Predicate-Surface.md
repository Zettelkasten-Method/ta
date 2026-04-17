---
title: "ADR-003: CLI Predicate Surface — Flag-Based AND Composition"
date: 2026-04-17
deciders:
  - Christian Tietze
consulted:
  - Claude Sonnet 4.5
status: accepted
related: []
---

# ADR-003: CLI Predicate Surface — Flag-Based AND Composition

## Context

The primary consumer of `zk-llm` is a coding agent composing retrieval queries programmatically. The surface area exposed to the agent determines:

- How easy it is for the agent to construct a well-formed query.
- How expressive the query language is without a full in-memory index.
- Whether escape sequences and quoting produce bugs when the agent assembles argv.

The Archive v2 uses `SearchExpressionParser` for full Boolean query evaluation (`tag:foo AND (bar OR NOT baz)`). That evaluator requires the complete in-memory index to be consulted — it cannot work incrementally against a streaming candidate set produced by `rg`. Since the CLI has no persistent index and builds no in-memory index between invocations, the full Boolean surface is not viable for this prototype.

We need a minimal surface that:

1. Lets agents compose meaningful narrowing queries.
2. Maps cleanly onto `rg -l` invocations that can be intersected.
3. Avoids nested-quote bugs when agents build the argv programmatically.
4. Is extensible later (OR/NOT) without breaking existing callers.

## Decision

We adopt **flag-based, repeatable predicates, AND-combined**:

```
zk-llm search [--tag TAG]... [--phrase STR]... [--word WORD]...
              [--depth N] [POSITIONAL_PHRASE]
```

- `--tag TAG` — repeatable. Narrows to notes structurally containing `#TAG`.
- `--phrase STR` — repeatable. Narrows to notes containing `STR` as a literal substring in non-code text.
- `--word WORD` — repeatable. Narrows to notes containing `WORD` with word-boundary matches in non-code text.
- `POSITIONAL_PHRASE` — optional single bare positional argument, treated as an implicit `--phrase`.
- All predicates AND-combined. Every predicate must be satisfied for the note to be retained.
- Zero predicates is an error (we require at least one).

`zk-llm tag TAGNAME` is a syntactic sugar for `zk-llm search --tag TAGNAME`.

### Rationale

- **Each predicate is exactly one argv token.** No nested quoting. Agents that build argv arrays programmatically (Python's `subprocess.run([...])`, Swift's `Process.arguments`, etc.) never hit escape bugs.
- **Repeatable flags mirror how agents think.** "Find notes tagged `foo` and `bar` containing the phrase `second-order thinking`" maps directly to `--tag foo --tag bar --phrase "second-order thinking"`.
- **AND-only is cheap and composable.** Each predicate becomes one `rg -l` invocation; results are intersected in Swift. O(predicates × files) in the worst case. No expression evaluator needed.
- **OR/NOT are synthesizable on the agent side.** For OR, the agent issues two separate `zk-llm search` calls and unions the YAML ref sets. For NOT, it filters its own working set. Agents are good at this.
- **The positional phrase reduces common-case friction.** `zk-llm search "mental models"` is the natural entry point; adding `--phrase` is boilerplate when that's the only predicate.

### Predicate → `rg` mapping

| Predicate | `rg` invocation |
|---|---|
| `--tag foo` | `rg -l '#foo\b' ARCHIVE` |
| `--phrase "hello world"` | `rg -l -F 'hello world' ARCHIVE` |
| `--word foo` | `rg -l -w -F 'foo' ARCHIVE` |

All predicates run their own `rg` pass; file lists are intersected in Swift. The intersected candidate set goes into Stage 2 (structural verification).

## Alternatives Considered

### A. Single prefix-token query string (notmuch / mu / mairix style)

```
zk-llm search 'tag:foo tag:bar "hello world" word:baz'
```

One argv argument, tokens inside separated by space, `tag:` and `word:` prefixes, bare tokens or quoted strings are phrases.

**Rejected because:** agents assembling this string must correctly escape embedded quotes and spaces. A tag named `foo bar` or a phrase with `tag:` inside it produces ambiguity or requires a second-level escape mechanism. Flag-based argv avoids all of this — each argv slot is unambiguous. The notmuch feel can be added additively later as a thin tokenizer over the same underlying predicate model, without breaking callers that use flags.

### B. Full Boolean DSL via SearchExpressionParser

```
zk-llm search 'tag:foo AND (bar OR baz) NOT qux'
```

**Rejected because:** the evaluator needs a full in-memory note index. Each `NOT` clause requires enumerating the set complement, which in turn requires knowing the full corpus. Our CLI is cold-start per invocation — building that index every call is exactly the daemonization problem we deferred. Additionally, Boolean expression semantics are more surface area for the agent to get right; flag-based AND is much harder to misuse.

### C. Positional-only predicate list

```
zk-llm search foo bar baz
```

All positional args implicitly AND'd as phrases.

**Rejected because:** cannot distinguish `foo` (phrase) from `tag:foo` (tag) without prefix syntax or separate subcommands. Adding prefix syntax puts us back at alternative A. Separate subcommands (`zk-llm search-text`, `zk-llm search-tags`) explode the command surface.

### D. `--query` with structured JSON

```
zk-llm search --query '{"tags":["foo"],"phrases":["bar"]}'
```

**Rejected because:** maximum escape-sequence liability. Every JSON quote inside a shell quote is a chance to mis-nest. Agents would reach for `jq` or similar to emit the string safely — extra tooling for zero gain. Flag-based argv already has this structure, one slot per value.

## Consequences

### Positive

- **Agent ergonomics.** The surface matches how argparse-style CLIs work everywhere; agent tool-use training data heavily favors this shape.
- **Cold-start compatible.** Each predicate maps to a single `rg` pass and a set intersection. No index, no actor, no daemon.
- **Extensible without breakage.** Adding `--exclude-tag`, `--regex`, `--since-date` later preserves existing call sites.
- **Testable.** Each predicate has a narrow unit-test surface (does `--tag foo` produce the right `rg` command-line? does structural verification reject a candidate where `#foo` only appears in code?).

### Negative

- **No OR.** Agents needing OR issue multiple calls and union results. Marginal extra latency on the agent side; trivial to implement; explicit in the trace.
- **No NOT.** Agents needing NOT filter their working set. Same trade-off as OR.
- **Predicate semantics differ from full-text search engines.** An agent trained on Elasticsearch might expect fielded Boolean queries. The CLI's narrower surface is by design and is documented.

### Neutral

- **No query language to version.** There are no syntactic breaking changes possible — only flag additions. Future migrations are purely additive.
