# TODO

Work queue for the 0.4.0 modernization pass. Consume top to bottom, one commit
per item, delete the item when merged. Delete this file when it is empty.

Each item is delegated to an implementer subagent; the controller reviews the
diff and runs `swift test` before committing. Re-evaluate the ordering and
value of remaining items after each one lands.

## 13. Docs drift

`docs/README.md` ADR table lacks ADR-006. Check CHANGELOG `[Unreleased]` has
an entry for every item above.

## 14. Tag matching: substring instead of exact

The GUI app matches tags by substring (`#dach` finds `#dachstuhl`); `ta`
requires an exact tag (spec line 299, ADR-003 line 61). Change both stages:
rg pattern `#dach` without `\b`, and the structural filter checks each
extracted tag with a case-insensitive `contains`. Write ADR-007 recording the
reversal, update the `ta-search` skill text. Discuss before implementing.
