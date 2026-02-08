# trustflow-env

Environment manifests for TrustFlow.

Promotions are manual: Actions only print `IMAGE_REF=...@sha256:...`; humans update
`environments/*/image-patch.yaml` and open PRs.

Key paths:

- `environments/dev/`, `environments/stage/`, `environments/prod/`
- `apps/` (base manifests for TrustFlow apps)
- `environments/*/` (kustomize overlays)

## TrustFlow core tooling

Cluster bootstrap, Kyverno policies, Argo CD extensions, verifier manifests, and Trivy tooling
have moved to the **`trustflow-core`** repo. If you were looking for:

- Kind bootstrap scripts
- Kyverno policy manifests
- Argo CD extension values/manifests
- Verifier deployment YAML
- Trivy operator pinning + scan scripts

Please refer to that repository instead.

## GitHub settings to enforce promotion gates

- Protect `main` and require the `verify-promotion` status check.
- Configure `CODEOWNERS` (see `CODEOWNERS`) + require code owner review for `/environments/prod/`.
