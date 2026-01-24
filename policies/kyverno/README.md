# Kyverno policies

These ClusterPolicies enforce TrustFlow’s threat model at cluster admission:

- **require-image-digest**: blocks `:tag` usage; requires `image@sha256:...`
- **verify-trustflow-app**: requires a valid Cosign keyless signature and a CycloneDX SBOM attestation

## Configure identity

Update `verify-trustflow-app.yaml` placeholders:

- `YOUR_GITHUB_ORG_OR_USER` (GHCR owner + GitHub repo owner)
- workflow identity in `subject` (must match what `cosign verify --certificate-identity ...` expects)

