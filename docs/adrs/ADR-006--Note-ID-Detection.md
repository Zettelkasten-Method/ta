---
title: "ADR-006: Note ID Detection"
date: 2026-05-27
deciders:
  - Christian Tietze
consulted:
  - Claude Opus 4.7
status: accepted
related:
  - ADR-001
---

# ADR-006: Note ID Detection

## Context

`ta` indexes a Zettelkasten by extracting a stable identifier from each note's filename. The ID is used for two purposes:

1. **Wiki-link target resolution.** `[[202503091430]]` must locate the file whose name carries that ID.
2. **Graph traversal.** Outgoing links produce neighbor candidates for depth-N expansion (see ADR-004).

Until this ADR, the extractor was hardcoded: a filename was indexed iff its first 12 characters were all digits. This matched the canonical The Archive convention (`YYYYMMDDHHMM Filename.md`) but excluded any other layout.

### Observed problem

A user reported that all searches returned `[]` despite a 1,200-note archive. Their filenames carried the ID at the **end**:

```
Thinking About Thinking - Cognitive Distancing 202506252102.md
```

The hardcoded prefix check rejected every file. `NoteParser` threw `missingTimestampPrefix`; `StructuralFilter` silently caught and skipped. The user saw no error, no warning — just empty results. Worse, even searches for terms that demonstrably did not exist returned the same empty result, so there was no way to distinguish "no match" from "no files indexed".

### Constraints

1. **Backward compatibility.** Existing users with prefix-timestamped archives must see identical behavior. No config migration; no new failure modes.
2. **Common Zettelkasten conventions.** Both prefix (`YYYYMMDDHHMM Title.md`) and suffix (`Title YYYYMMDDHHMM.md`) layouts are used in the wild. Mid-filename IDs are rarer but should not be excluded by design.
3. **User override.** Some archives use 14-digit IDs (`YYYYMMDDHHMMSS`), short IDs, or alphanumeric schemes. The extractor must be replaceable without code changes.
4. **Silent failure must be visible.** Whatever the default, users whose archives don't match should be able to diagnose it without reading the source.

## Decision

The default ID pattern is the unanchored regex:

```
\d{12}
```

Applied to the filename stem (filename without extension). All non-overlapping matches become index keys; a file with two 12-digit sequences is reachable via either. The first match becomes the canonical `timestampID` in `ParsedNote`.

The pattern is configurable via `~/.config/ta/config.yaml`:

```yaml
archive: ~/Zettelkasten
id_pattern: "\\d{12}"
```

An invalid regex source falls back to the default with a verbose-mode warning rather than crashing.

When `--verbose` is set, every file the indexer skips is logged with the reason (`skip (extension)`, `skip (no ID match)`) and the resolved `id_pattern` is echoed with its provenance (`default` or `config`).

### Rationale

- **Unanchored over `^\d{12}`.** The anchored form is one character shorter to write but excludes suffix and mid-name layouts that are common in user archives. The unanchored form is a strict superset: every filename that matched `^\d{12}` still matches `\d{12}`, and the extracted ID is the same 12-digit sequence. Backward compatibility is preserved automatically.

- **12 digits, not "any digits".** A pattern like `\d+` matches `1` inside `Chapter 1.md`, polluting the index with spurious IDs. Twelve digits is The Archive's documented convention and is rare enough in incidental filename content to be safe.

- **All matches, not just the first.** A filename like `202501011200 cross-ref 202501011201.md` is unusual but unambiguous — both IDs identify the same file, and `[[202501011200]]` and `[[202501011201]]` should both resolve to it. The cost is a few extra dictionary entries; the alternative (only-leftmost) silently drops a working wiki-link target.

- **Filename stem, not full filename.** The extension (`.md`, `.txt`) is excluded from the match so that an ID like `202503091430` does not accidentally match digits within an extension or filesystem decoration.

- **Verbose logging is part of the contract.** Without it, the previous silent-skip failure mode would recur for any user whose archive doesn't match the default. The flag is global so it works for `search`, `tag`, and `show` uniformly.

## Alternatives Considered

### A. Keep `^\d{12}` (prefix only); document suffix as unsupported

Status quo plus a docs update.

**Rejected because:** the problem was not lack of documentation; the user had read the README and configured the archive correctly. The defaulting itself is the failure point. A docs change does nothing for the users who silently get empty results.

### B. Unanchored `\d{12}` as default, no configurability

Same default behavior, but the regex is hardcoded.

**Rejected because:** 14-digit timestamps (`YYYYMMDDHHMMSS`) and shorter `YYYYMMDDHHMM`-without-minute layouts both exist. Hardcoding the digit count would only kick the can down the road to the next user with a non-12 scheme. The marginal cost of a config key is one YAML parse and one regex compile at startup — negligible.

### C. Anchored `\d{12}` with `--id-pattern` flag override

Keep the strict default; require users to opt in via CLI flag for non-prefix layouts.

**Rejected because:** the flag would have to be passed on every invocation, including from coding agents that compose `ta` calls. A persistent config setting belongs in the config file, not on the command line. The flag adds friction without solving the discovery problem (users don't know to look for it until something goes wrong).

### D. Auto-detect from filename samples

Scan the archive at startup, infer the pattern from majority filename shape, set it as the active pattern for the session.

**Rejected because:** auto-detection has its own silent-failure mode — when it guesses wrong, the user has no idea why some files are missing. The verbose-logging approach surfaces the actual decision (here is the pattern, here are the files that didn't match) which is strictly more debuggable than a heuristic the user can't see.

### E. Require an explicit `id` field in note frontmatter

Index by an in-file YAML key rather than the filename.

**Rejected because:** The Archive's convention is filename-based and there is significant inertia behind it. Requiring frontmatter would force every user to migrate every note. Out of scope for the prototype.

## Consequences

### Positive

- **Existing archives keep working unchanged.** The default is a strict generalization of the previous behavior.
- **Suffix and mid-name layouts work out of the box.** No config required.
- **Custom schemes are supported via one config line.** 14-digit IDs, alphanumeric IDs, project-specific patterns.
- **Silent-skip failure mode is gone.** `--verbose` shows every skipped file and the reason.

### Negative

- **Edge case: filenames containing non-ID 12-digit runs.** A filename like `Phone number 415-555-0100 list 202503091430.md` would index under both `4155550100` (if 12 digits) and the real ID. In practice 10-digit phone numbers don't trigger the 12-digit pattern, and the malformed case (a 12-digit ID-shaped number that isn't an ID) is a user-discipline issue.
- **No validation that the user's `id_pattern` is "reasonable".** A pattern of `\d+` will produce noisy indexes; we don't reject it. Trusting the user is the right default; the verbose logging exposes the consequences.

### Neutral

- The static helper `NoteIndex.extractTimestampPrefix(_:)` is removed. It was no longer called after the refactor; `IDPattern.extractIDs(from:)` is the replacement.
- The wiki-link resolver gained a layered fallback (exact ID → filename substring → ID prefix). The substring layer is what makes `[[Cognitive Distancing]]` resolve to a suffix-timestamped file. This is covered in the implementation but does not require its own ADR — it is a natural consequence of having stem strings available for the index.
