#!/usr/bin/env bash
set -euo pipefail

root="${1:-.}"

# Extract pinned images (`image: ...@sha256:...`) from YAML.
# This is intentionally strict to enforce "promote by digest".
pattern='^\s*image:\s*[^ ]+@sha256:[a-f0-9]{64}\s*$'
if command -v rg >/dev/null 2>&1; then
  rg -n --no-filename "$pattern" "$root"
else
  grep -RIn -- "$pattern" "$root" || true
fi \
  | sed -E 's/^\s*image:\s*//; s/\s*$//' \
  | sort -u
