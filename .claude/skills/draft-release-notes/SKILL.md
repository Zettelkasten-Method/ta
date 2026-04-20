---
name: draft-release-notes
description: Use when preparing a `ta` release — after `mise run release` writes artifacts to `dist/`, or when the user asks to draft, prepare, or update release notes for version X.Y.Z. Produces `dist/ta-X.Y.Z-release-notes.md` for pasting into the Codeberg / GitHub release body. Forge upload stays manual.
---

# Draft release notes for `ta`

Assemble `dist/ta-$VERSION-release-notes.md` from the CHANGELOG entry, the signed artifacts in `dist/`, and a small install / verification template. The file lives next to the artifacts it describes, not in `/tmp/`, so the maintainer can find it on re-run.

## Preflight

Refuse and point at `mise run release` if any required input is missing:

```bash
VERSION=$(scripts/get-version.sh)
PKG="dist/ta-${VERSION}-macos-universal.pkg"
TAR="dist/ta-${VERSION}-macos-universal.tar.gz"
SUMS="dist/SHA256SUMS"
test -f "$PKG" && test -f "$TAR" && test -f "$SUMS" \
  || { echo "Missing dist/ artifacts for ${VERSION}. Run 'mise run release' first." >&2; exit 1; }
```

## Gather inputs

```bash
PKG_BYTES=$(stat -f %z "$PKG")
TAR_BYTES=$(stat -f %z "$TAR")
PKG_MB=$(awk "BEGIN{printf \"%.1f\", ${PKG_BYTES}/1048576}")
TAR_MB=$(awk "BEGIN{printf \"%.1f\", ${TAR_BYTES}/1048576}")

PKG_SHA=$(awk -v f="$(basename "$PKG")" '$2==f{print $1}' "$SUMS")
TAR_SHA=$(awk -v f="$(basename "$TAR")" '$2==f{print $1}' "$SUMS")

REPO_URL=$(git remote get-url origin \
  | sed -E 's#^ssh://git@#https://#; s#\.git$##')
```

## Slice CHANGELOG

Extract the block for `[$VERSION]` from `CHANGELOG.md`: every line after `## [$VERSION] - YYYY-MM-DD` up to (but not including) the next `## [` heading or the first footer reference (a line matching `^\[[^]]+\]: `), whichever comes first.

```bash
CHANGELOG_BLOCK=$(awk -v ver="$VERSION" '
  $0 ~ "^## \\[" ver "\\]" { found=1; next }
  found && /^## \[/        { exit }
  found && /^\[[^]]+\]: /  { exit }
  found                     { print }
' CHANGELOG.md)

TAGLINE=$(printf '%s\n' "$CHANGELOG_BLOCK" | awk 'NF{print; exit}')
```

Preserve blank lines, `### Subsection` headings, and bullet formatting verbatim.

## Write the file

Write to `dist/ta-${VERSION}-release-notes.md` using the template below. Substitute all `${...}` variables. Keep the markdown backticks as literals. The triple-backtick fences inside the template stay as-is.

~~~markdown
${TAGLINE}

macOS universal binary (arm64 + x86_64). Developer ID signed, notarized by Apple.

## Install

### Option A: `.pkg` installer (recommended)

Download `ta-${VERSION}-macos-universal.pkg` and double-click, or:

```bash
sudo installer -pkg ta-${VERSION}-macos-universal.pkg -target /
```

Installs `ta` to `/usr/local/bin/ta`. Signed with Developer ID Installer (Christian Tietze, team `FRMDA3XRGC`), notarized by Apple, and the notarization ticket is stapled to the `.pkg` — Gatekeeper-clean on first run.

### Option B: `.tar.gz` tarball

```bash
tar -xzf ta-${VERSION}-macos-universal.tar.gz
sudo mv ta-${VERSION}-macos-universal/ta /usr/local/bin/
xattr -d com.apple.quarantine /usr/local/bin/ta
```

The binary is signed with Developer ID Application (hardened runtime + secure timestamp). Apple doesn't support stapling a notarization ticket to a bare Mach-O, so the quarantine flag has to be cleared manually on first run — Option A avoids this.

### Option C: Build from source

```bash
git clone ${REPO_URL} && cd ta
swift build -c release
./.build/release/ta --help
```

## Assets

| File | Architecture | Size | SHA-256 |
|---|---|---|---|
| `ta-${VERSION}-macos-universal.pkg` | arm64 + x86_64 | ${PKG_MB} MB | `${PKG_SHA}` |
| `ta-${VERSION}-macos-universal.tar.gz` | arm64 + x86_64 | ${TAR_MB} MB | `${TAR_SHA}` |

## Verify integrity

Hash verification against the published `SHA256SUMS`:

```bash
shasum -a 256 -c SHA256SUMS
```

Signature + notarization — the authoritative integrity check:

```bash
pkgutil --check-signature ta-${VERSION}-macos-universal.pkg
spctl --assess --type install -vv ta-${VERSION}-macos-universal.pkg
```

Expect `Developer ID Installer: Christian Tietze (FRMDA3XRGC)` and `source=Notarized Developer ID`.

For the tarball, verify the extracted binary's embedded Developer ID Application signature:

```bash
codesign -dv --verbose=4 /usr/local/bin/ta
```

## Runtime dependencies

- `rg` (ripgrep) on `$PATH` is preferred for search.
- Falls back to `grep -l -r` if `rg` is absent.

## What's in ${VERSION}

${CHANGELOG_BLOCK}
~~~

## After writing

Report:

- Output path: `dist/ta-${VERSION}-release-notes.md`.
- Still manual: `git tag -a ${VERSION} -m "${VERSION}"` + push; upload `.pkg`, `.tar.gz`, `SHA256SUMS` to the forge; paste file contents as release body.
- If reusing an existing tag's release page, delete old assets before uploading new ones — Codeberg's web UI does not clobber by filename.

## Drift check

Three signing/packaging claims in the template above are pinned to this repo's `mise.toml` values: the team ID `FRMDA3XRGC`, the "Christian Tietze" cert CN, and the `arm64 + x86_64` universal build. If `docs/packaging.md` sections **"What each signed artifact looks like"** or **"Integrity anchors"** have changed since this skill was last edited, re-read them and update Option A and Option B wording before writing. The template reflects the 2026-04 pipeline: `.pkg` is signed + notarized + stapled; `.tar.gz` contains a Developer ID Application signed binary with hardened runtime but no stapled ticket.
