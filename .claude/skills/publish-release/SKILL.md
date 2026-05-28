---
name: publish-release
description: Use when the user wants to publish, ship, or push a `ta` release to Codeberg and GitHub — after release notes exist in `dist/`. Pushes the tag, creates the Codeberg release with `fgj`, waits for the auto-mirror to sync the tag to GitHub, then creates the GitHub release with `gh`. If the mirror hasn't synced within ~2 minutes, pushes directly to the `github` remote. Trigger when the user says "publish release", "ship it", "push the release", "create the release", or similar.
---

# Publish a `ta` release

Push the version tag and create releases on Codeberg and GitHub, attaching signed artifacts from `dist/`.

Codeberg is the primary forge. GitHub is a mirror — Codeberg auto-syncs commits and tags, but releases (with attached assets) must be created on both sides.

## Preflight

Determine the version tag, then verify everything needed is in place. Refuse clearly if anything is missing.

```bash
VERSION=$(scripts/get-version.sh)
```

Check each of these. Stop and tell the user what's missing:

| Check | How |
|---|---|
| Release notes | `test -f dist/ta-${VERSION}-release-notes.md` |
| `.pkg` artifact | `test -f dist/ta-${VERSION}-macos-universal.pkg` |
| `.tar.gz` artifact | `test -f dist/ta-${VERSION}-macos-universal.tar.gz` |
| `SHA256SUMS` | `test -f dist/SHA256SUMS` |
| Git tag exists locally | `git tag -l "$VERSION"` is non-empty |
| Tag points at HEAD | `git rev-parse "$VERSION"` equals `git rev-parse HEAD` |
| Working tree clean | `git status --porcelain` is empty |
| `fgj` available | `command -v fgj` |
| `gh` available | `command -v gh` |

If release notes are missing, tell the user to run the `draft-release-notes` skill first.
If artifacts are missing, tell the user to run `mise run release` first.

## Step 1: Push the tag to Codeberg

```bash
git push origin "$VERSION"
```

Also push `main` if it's ahead of `origin/main`:

```bash
git push origin main
```

## Step 2: Create the Codeberg release

Derive the Codeberg repo slug from the `origin` remote:

```bash
CODEBERG_REPO=$(git remote get-url origin | sed -E 's#.*/([^/]+/[^/]+?)(\.git)?$#\1#')
```

Create the release and attach all three artifacts:

```bash
fgj release create "$VERSION" \
  "dist/ta-${VERSION}-macos-universal.pkg" \
  "dist/ta-${VERSION}-macos-universal.tar.gz" \
  dist/SHA256SUMS \
  --title "$VERSION" \
  --notes-file "dist/ta-${VERSION}-release-notes.md" \
  --repo "$CODEBERG_REPO"
```

Report the Codeberg release URL.

## Step 3: Wait for the GitHub mirror

Codeberg auto-mirrors to `github` (remote `github` in this repo, pointing at `Zettelkasten-Method/ta`). The tag usually appears on GitHub within a minute. Check for it before creating the GitHub release:

```bash
GITHUB_REPO=$(git remote get-url github | sed -E 's#.*/([^/]+/[^/]+?)(\.git)?$#\1#')
```

Poll `gh api repos/$GITHUB_REPO/git/ref/tags/$VERSION` up to 4 times, 30 seconds apart. If the tag appears, move on to Step 4.

If after ~2 minutes the tag still hasn't appeared, push directly:

```bash
git push github main --tags
```

Tell the user the mirror didn't sync in time and you pushed manually.

## Step 4: Create the GitHub release

```bash
gh release create "$VERSION" \
  "dist/ta-${VERSION}-macos-universal.pkg" \
  "dist/ta-${VERSION}-macos-universal.tar.gz" \
  dist/SHA256SUMS \
  --title "$VERSION" \
  --notes-file "dist/ta-${VERSION}-release-notes.md" \
  --repo "$GITHUB_REPO"
```

Report the GitHub release URL.

## Summary

After both releases exist, report:

- Codeberg release URL
- GitHub release URL
- Whether the mirror synced automatically or needed a manual push
