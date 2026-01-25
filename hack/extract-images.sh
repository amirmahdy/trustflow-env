#!/usr/bin/env bash
set -euo pipefail

root="${1:-.}"

# Extract pinned images (`image: ...@sha256:...`) from YAML.
# This is intentionally strict to enforce "promote by digest".
pattern_rg='^[[:space:]]*image:[[:space:]]*[^ ]+@sha256:[a-f0-9]{64}'
pattern_grep='^[[:space:]]*image:[[:space:]]*[^ ]+@sha256:[a-f0-9]{64}'
if command -v rg >/dev/null 2>&1; then
  rg -o --no-filename "$pattern_rg" "$root"
else
  grep -RhoE -- "$pattern_grep" "$root" || true
fi \
  | sed -E 's/^[[:space:]]*image:[[:space:]]*//; s/[[:space:]]*$//' \
  | sort -u
