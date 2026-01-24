#!/usr/bin/env bash
set -euo pipefail

if ! command -v cosign >/dev/null 2>&1; then
  echo "cosign is required on PATH" >&2
  exit 2
fi

root="${1:-.}"

issuer="${COSIGN_OIDC_ISSUER:-https://token.actions.githubusercontent.com}"
identity="${COSIGN_CERT_IDENTITY:-}"
identity_regexp="${COSIGN_CERT_IDENTITY_REGEXP:-}"

if [[ -z "${identity}" && -z "${identity_regexp}" ]]; then
  echo "Set COSIGN_CERT_IDENTITY (exact) or COSIGN_CERT_IDENTITY_REGEXP (regex) for keyless verification." >&2
  exit 2
fi

mapfile -t images < <("$(dirname "$0")/extract-images.sh" "$root")
if [[ ${#images[@]} -eq 0 ]]; then
  echo "No pinned images found under: $root" >&2
  exit 2
fi

for img in "${images[@]}"; do
  echo "Verifying signature: $img"
  if [[ -n "${identity}" ]]; then
    cosign verify --certificate-oidc-issuer "$issuer" --certificate-identity "$identity" "$img" >/dev/null
  else
    cosign verify --certificate-oidc-issuer "$issuer" --certificate-identity-regexp "$identity_regexp" "$img" >/dev/null
  fi

  echo "Verifying SBOM attestation: $img"
  # Enforces a CycloneDX SBOM attestation produced by `cosign attest --type cyclonedx`.
  if [[ -n "${identity}" ]]; then
    cosign verify-attestation --type cyclonedx --certificate-oidc-issuer "$issuer" --certificate-identity "$identity" "$img" >/dev/null
  else
    cosign verify-attestation --type cyclonedx --certificate-oidc-issuer "$issuer" --certificate-identity-regexp "$identity_regexp" "$img" >/dev/null
  fi
done

echo "OK: all images are signed + SBOM-attested"

