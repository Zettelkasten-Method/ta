#!/usr/bin/env bash
# Print the CLI's declared version by reading the source of truth directly.
# Used by mise release tasks so artifact filenames don't depend on being able
# to run the binary, and don't drift from the declared version.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sed -nE 's/^[[:space:]]*version: "([^"]+)".*/\1/p' \
  "$repo_root/Sources/ta/TheArchiveCLI.swift" | head -n1
