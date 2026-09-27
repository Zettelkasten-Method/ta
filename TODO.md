# TODO

Work queue for the 0.4.0 modernization pass. Consume top to bottom, one commit
per item, delete the item when merged. Delete this file when it is empty.

Each item is delegated to an implementer subagent; the controller reviews the
diff and runs `swift test` before committing. Re-evaluate the ordering and
value of remaining items after each one lands.

## 4. Dedupe YAML helpers, stop re-reading files in `ShowEmitter`

`yamlString` / `yamlFlowList` are duplicated in `SearchYAMLEmitter` and
`ShowEmitter`. Extract one internal helper. `ShowEmitter` re-reads the file it
already parsed; use `note.rawText`. Output must stay byte-identical
(ADR-004, ADR-005); existing emitter tests guard this.

## 5. Enums for `archiveSource` / `idPatternSource`

`ResolvedConfig` carries two stringly typed source labels. Replace with small
enums that render the same words in verbose logs.

## 6. `String.Index` instead of integer offsets in `StructuralFilter`

`firstPassingOffset` and `snippet` convert to and from integer offsets, each
an O(n) walk per predicate per candidate. Carry `String.Index` through and
slice directly. Snippet output must not change.

## 7. Drop the `which` probe in `RipgrepRunner`

`hasTool` spawns an extra process per search. `/usr/bin/env rg` exits 127
when rg is missing; fall back to grep on that status instead.

## 8. `Logger`: real `Sendable`

Make `sink` `@Sendable`, remove `@unchecked`, delete the pointless
`@usableFromInline` on `defaultSink`.

## 9. Swift `Regex` where it fits

`WikiLinkRegex`, `IDPattern`, and the `\b` word match in `StructuralFilter`
can use Swift `Regex`. Not `HashtagRegex`: Swift 6.3 `Regex` still rejects
lookbehind (verified), and ADR-002 pins that pattern. Behavior must stay
identical; the regex tests guard this. Re-evaluate: skip if the gain is only
cosmetic.

## 10. Modern Foundation API

`URL(filePath:)` / `appending(path:)` everywhere (already mixed),
`String(contentsOf:encoding:)` instead of `Data` round-trips,
`FileHandle.write(contentsOf:)`, replace `NSString` path helpers
(`expandingTildeInPath`, `deletingPathExtension`).

## 11. Delete dead API

`ArchiveResolver.resolve()`, `ShowEmitter.emit(refs:)`, and
`ParsedNote.nonCodeText` / `unresolvedLinkText` are test-only. Delete them
and adjust tests to assert through the public path, or justify keeping each.

## 12. Small tidies

- `NonCodeTextExtractor.extract` copies the buffer for no reason.
- `GraphExpander` frontier tuple wants a named struct; `currentDepth` from
  `first?.depth` is fragile.
- `--depth` above 10 silently clamps; reject via ArgumentParser `validate()`
  with a clear message, or document the clamp. Decide.

## 13. Docs drift

`docs/README.md` ADR table lacks ADR-006. Check CHANGELOG `[Unreleased]` has
an entry for every item above.

## 14. Tag matching: substring instead of exact

The GUI app matches tags by substring (`#dach` finds `#dachstuhl`); `ta`
requires an exact tag (spec line 299, ADR-003 line 61). Change both stages:
rg pattern `#dach` without `\b`, and the structural filter checks each
extracted tag with a case-insensitive `contains`. Write ADR-007 recording the
reversal, update the `ta-search` skill text. Discuss before implementing.
