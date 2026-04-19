# Packaging & release

Automated with [mise](https://mise.jdx.dev/). All tasks live in `mise.toml` at the repo root.

Run `mise tasks` to list; `mise run <name>` to execute.

## Quick reference

| Task | What it does |
|---|---|
| `mise run verify-setup` | Check Developer ID certs + notarytool profile are present |
| `mise run build` | `swift build -c release --arch arm64 --arch x86_64` |
| `mise run sign` | Codesign binary with Developer ID Application + hardened runtime |
| `mise run pkg` | Build `.pkg` installer + sign with Developer ID Installer |
| `mise run notarize` | Submit `.pkg` to Apple notary + staple ticket |
| `mise run tarball` | Bundle signed binary + docs as `.tar.gz` |
| `mise run sums` | Write SHA-256 sums for release assets |
| `mise run release` | Full pipeline: everything above, in order |
| `mise run clean` | `rm -rf .build dist` |

Dependencies are wired: `mise run release` pulls build → sign → pkg → notarize → tarball → sums automatically.

## One-time setup

### 1. Apple Developer Program

Requires an active [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/year).

### 2. Install both Developer ID certs

In [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates/list), create (or download) **both**:

- `Developer ID Application` — signs the Mach-O binary.
- `Developer ID Installer` — signs the `.pkg` wrapper.

Double-click the downloaded `.cer` files to install them into your login keychain. Verify:

```bash
security find-identity -v | grep "Developer ID"
```

You should see at least one of each.

### 3. Store notarytool credentials in the keychain

Generate an [App Store Connect API key](https://appstoreconnect.apple.com/access/api) (Developer role is enough) **or** an [app-specific password](https://support.apple.com/en-us/HT204397) for your Apple ID.

Then:

```bash
xcrun notarytool store-credentials ta-notary \
  --apple-id YOUR_APPLE_ID \
  --team-id FRMDA3XRGC \
  --password APP_SPECIFIC_PASSWORD
```

Or with an API key:

```bash
xcrun notarytool store-credentials ta-notary \
  --key ~/path/to/AuthKey_XXXXXX.p8 \
  --key-id XXXXXX \
  --issuer UUID-FROM-APP-STORE-CONNECT
```

The profile name `ta-notary` matches the default `NOTARY_PROFILE` env var in `mise.toml`. Pick any name — just override in `mise.local.toml` if you change it.

### 4. Verify

```bash
mise run verify-setup
```

Should print `All prerequisites present.` If any check fails, the output says which one and why.

## Per-developer overrides

Create `mise.local.toml` (gitignored) to override any env var from `mise.toml`:

```toml
[env]
DEV_ID_APP = "Developer ID Application: Your Name (YOURTEAM)"
DEV_ID_INSTALLER = "Developer ID Installer: Your Name (YOURTEAM)"
NOTARY_PROFILE = "my-profile"
PKG_IDENTIFIER = "com.yourdomain.ta"
```

## Releasing from a fork

If you're distributing your own build of `ta` under your Apple Developer account:

1. Install both Developer ID certs (see [§2](#2-install-both-developer-id-certs)).
2. Store notary creds under a profile name of your choice (see [§3](#3-store-notarytool-credentials-in-the-keychain)).
3. Create `mise.local.toml` at the repo root (gitignored) overriding at minimum the four env vars shown under [Per-developer overrides](#per-developer-overrides).
4. Run `mise run verify-setup` — confirms your identities, notary profile, and toolchain are wired up.
5. Run `mise run release` — artifacts land in `dist/`.

## Bumping the version

The version lives as `version: "X.Y.Z"` in `Sources/ta/TheArchiveCLI.swift` and is read by `scripts/get-version.sh` so artifact filenames stay in lockstep with the declared version. To bump:

1. Edit `Sources/ta/TheArchiveCLI.swift`.
2. Add a new `## [X.Y.Z] - YYYY-MM-DD` block at the top of `CHANGELOG.md` (move `[Unreleased]` content into it).
3. `mise run release`.
4. `git tag -a X.Y.Z -m "X.Y.Z"` and push.
5. Create the release on the forges (Codeberg + GitHub) with the artifacts from `dist/`.

## What each signed artifact looks like

After `mise run release`, `dist/` contains:

- `ta-X.Y.Z-macos-universal.pkg` — Developer ID Installer-signed, contains Developer ID Application-signed binary, notarized and stapled. Gatekeeper-clean on first run.
- `ta-X.Y.Z-macos-universal.tar.gz` — same signed binary plus `README.md`, `LICENSE`, `CHANGELOG.md`. Gatekeeper will still quarantine the binary when extracted from a tarball downloaded via browser (stapling doesn't apply to bare Mach-O). Users need `xattr -d com.apple.quarantine ta` or right-click → Open the first time.
- `SHA256SUMS` — hashes for both, for release notes.

### Integrity anchors

The `.pkg` is the authoritative integrity artifact: its Developer ID Installer signature and Apple notarization ticket are verifiable offline with `pkgutil --check-signature` and `spctl --assess --type install`. `SHA256SUMS` is a convenience for detecting transport corruption or mismatched artifacts on the release page; it is not itself signed. The `.tar.gz` has no stapled ticket (Apple doesn't support stapling to tarballs), so users extracting it must rely on the embedded binary's Developer ID Application signature (`codesign -dv --verbose=4 ta`) for verification.

### Entitlements

`ta` ships with no entitlements file — it's a pure CLI with no JIT, no DYLD injection, and no disabled library validation. The hardened runtime's secure defaults apply.

## Why a `.pkg`?

Apple doesn't let you staple a notarization ticket onto a bare Mach-O — only bundles, `.pkg`, and `.dmg` can carry tickets offline. For a CLI the canonical path is to wrap the signed binary in a `.pkg`, notarize + staple that, and ship it.

The `.tar.gz` is shipped as an alternative for users who prefer to manage `/usr/local/bin/` themselves, at the cost of the first-run quarantine dance.
