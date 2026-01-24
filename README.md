# trustflow-env

Environment manifests and policy gates for TrustFlow.

- Deployments pin images by digest (`image@sha256:...`)
- PR checks verify Cosign signature + CycloneDX SBOM attestation before promotion
- Kyverno policies can enforce the same at cluster admission

Key paths:

- `environments/dev/`, `environments/stage/`, `environments/prod/`
- `policies/kyverno/` (ClusterPolicies)
- `hack/verify-images.sh` (used by CI to verify signature + attestation)

## Local kind demo

Prereqs: `kind`, `kubectl`, `helm`

- Create cluster + install Kyverno + apply policies + deploy dev overlay:
  - `bash hack/kind-up.sh dev`
- Tear down:
  - `bash hack/kind-down.sh`

## GitHub settings to enforce promotion gates

- Protect `main` and require the `verify-promotion` status check.
- Configure `CODEOWNERS` (see `CODEOWNERS`) + require code owner review for `/environments/prod/`.
