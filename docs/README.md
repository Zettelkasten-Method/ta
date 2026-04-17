---
title: "zk-llm — Documentation Index"
date: 2026-04-17
---

# zk-llm — Documentation

This directory holds the design documentation for the `zk-llm` CLI prototype. The layout mirrors the convention used by The Archive v2 (`~/Areas/TheArchive2/docs/`).

## Directory layout

| Path | Contents |
|------|----------|
| `docs/adrs/` | Architectural Decision Records — immutable once accepted |
| `docs/superpowers/specs/` | Design specs produced via the `superpowers:brainstorming` workflow |

There are no PRDs, SDDs, or guides yet — the prototype is small enough to live inside a single spec plus a handful of ADRs. If the CLI grows into something longer-lived, we can add those subtrees following The Archive v2's conventions.

## Start here

1. **[`superpowers/specs/2026-04-17-zk-llm-cli-design.md`](superpowers/specs/2026-04-17-zk-llm-cli-design.md)** — the canonical design for the prototype. Read this first.
2. The ADRs below capture specific decisions cited by the design spec.

## Architectural Decision Records

| ADR | Subject |
|-----|---------|
| [ADR-001](adrs/ADR-001--Wiki-Link-Recognition-Regex.md) | Wiki-link recognition regex (`[[target]]`, `[[target\|display]]`) ported from The Archive v1 |
| [ADR-002](adrs/ADR-002--Hashtag-Recognition-Regex.md) | Hashtag recognition regex (`#tag`) ported from The Archive v1 |
| [ADR-003](adrs/ADR-003--CLI-Predicate-Surface.md) | CLI predicate surface — flag-based AND composition (`--tag`, `--phrase`, `--word`) |
| [ADR-004](adrs/ADR-004--Search-Output-Flat-YAML.md) | `zk-llm search` / `zk-llm tag` output as flat YAML with `depth` and `via` metadata |
| [ADR-005](adrs/ADR-005--Show-Output-Frontmatter-And-Raw-Markdown.md) | `zk-llm show` output as YAML frontmatter + raw markdown body |

## Document conventions

### ADRs

- **Filename:** `ADR-NNN--Title-With-Dashes.md`.
- **Frontmatter:** `title`, `date`, `deciders`, `status`, optional `related`. See any existing ADR for an example.
- **Structure:** Context → Decision → Alternatives Considered → Consequences.
- **Mutability:** Decision and Context sections are immutable once accepted. Reference sections (forward-pointers like `### Related Specs`) may be updated for navigability — references are a bibliography, not part of the decision.
- **Cross-references:** use bare names like `ADR-003`, not filenames. The filename is filesystem metadata; references are logical pointers.

### Design specs

- Produced via the `superpowers:brainstorming` workflow.
- **Filename:** `YYYY-MM-DD-<topic>-design.md`.
- **Living document:** revised as design evolves or implementation reveals issues.
- **Traceability:** cite the ADRs that inform specific decisions, so the "why" stays discoverable when the "what" changes.

## Relationship to The Archive v1 and v2

- **The Archive v1** ships today and uses `lib.multimarkdown6`. The zk-llm CLI borrows v1's wiki-link and hashtag regexes (ADR-001, ADR-002) but does not link against v1 at runtime.
- **The Archive v2** is the in-progress rewrite documented at `~/Areas/TheArchive2/docs/`. The zk-llm CLI borrows several concepts from its specs (NoteRef as filename, prefix-based ID resolution, tag extraction semantics) but is an independent codebase. Several v2 ADRs (ADR-010, ADR-013, ADR-020) and SDDs (Note-Discovery, Tag-Index) are cited from the zk-llm design spec where they are the authoritative source.
- **zk-llm** itself is a one-day prototype aimed at demonstrating agent-driven retrieval over a Zettelkasten. It is not intended to be folded back into either v1 or v2 as-is.
