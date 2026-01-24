#!/usr/bin/env bash
set -euo pipefail

from_env="${1:?from env (dev|stage)}"
to_env="${2:?to env (stage|prod)}"

from_file="environments/${from_env}/image-patch.yaml"
to_file="environments/${to_env}/image-patch.yaml"

if [[ ! -f "$from_file" ]]; then
  echo "Missing: $from_file" >&2
  exit 2
fi
if [[ ! -f "$to_file" ]]; then
  echo "Missing: $to_file" >&2
  exit 2
fi

from_image="$(sed -nE 's/^\s*image:\s*([^ ]+)\s*$/\1/p' "$from_file" | head -n1)"
if [[ -z "$from_image" ]]; then
  echo "No image found in: $from_file" >&2
  exit 2
fi

if ! [[ "$from_image" =~ @sha256:[a-f0-9]{64}$ ]]; then
  echo "Source image is not digest-pinned: $from_image" >&2
  exit 2
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

sed -E "s|^(\s*image:\s*).*$|\\1${from_image}|" "$to_file" > "$tmp"
mv "$tmp" "$to_file"

echo "Promoted:"
echo "- from: $from_env -> $from_image"
echo "- to:   $to_env -> updated $to_file"

