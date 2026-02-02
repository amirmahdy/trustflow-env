# trustflow-env

Environment manifests and policy gates for TrustFlow.

- Deployments pin images by digest (`image@sha256:...`)
- PR checks verify Cosign signature + CycloneDX SBOM attestation before promotion
- Kyverno policies can enforce the same at cluster admission
- Promotions are manual: Actions only print `IMAGE_REF=...@sha256:...`; humans update `environments/*/image-patch.yaml` and open PRs

Key paths:

- `environments/dev/`, `environments/stage/`, `environments/prod/`
- `policies/kyverno/` (ClusterPolicies)
- `scripts/verify-images.sh` (used by CI to verify signature + attestation)

## Local kind demo

Prereqs: `kind`, `kubectl`, `helm`

- Create cluster + install Kyverno + apply policies + deploy dev overlay:
  - `bash hack/kind-up.sh dev`
- Tear down:
  - `bash hack/kind-down.sh`

## Argo CD TrustFlow UI extension (kind)

This adds a TrustFlow tab to Argo CD resources and wires in Trivy Operator + a verifier backend.

### 1) Install Trivy Operator

If `require-image-digest` is enforced, install with the digest-pinned values file.

```bash
helm repo add aquasecurity https://aquasecurity.github.io/helm-charts/
helm repo update
helm upgrade --install trivy-operator aquasecurity/trivy-operator -n trivy-system --create-namespace -f trivy/trivy-operator-digests.yaml
kubectl get pods -n trivy-system
kubectl get vulnerabilityreports.aquasecurity.github.io -A
```

### 2) Build + publish the TrustFlow extension bundle

```bash
cd ../trustflow-argocd-extension
npm run build
npm run package
```

Upload `dist/extension-trustflow.tar` somewhere reachable by the `argocd-server` pod and update
`EXTENSION_URL` in `argocd/argocd-server-extensions-patch.yaml`. The argocd-server pod must have network access
to the URL.

### 3) Deploy the TrustFlow verifier backend

```bash
kubectl create namespace argocd
kubectl apply -f argocd/trustflow-verifier.yaml
```

Update the `COSIGN_CERT_IDENTITY_REGEXP` and image in the manifest to match your GHCR org/repo.

### 4) Enable proxy extensions in Argo CD

```bash
kubectl apply -f argocd/argocd-proxy-extension.yaml
```

If you are running Argo CD < 2.11, restart `argocd-server` after changing proxy extension settings.

### 5) Install UI extensions in argocd-server

If you are using Helm, you can patch the `argocd-server` deployment with the initContainers from
`argocd/argocd-server-extensions-patch.yaml` (or use `argocd/argocd-server-extensions-values.yaml`).

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace

kubectl patch deployment argocd-server -n argocd --patch-file argocd/argocd-server-extensions-patch.yaml
kubectl rollout restart deployment argocd-server -n argocd
```

Or with Helm:

```bash
helm upgrade --install argocd argo/argo-cd -n argocd -f argocd/argocd-server-extensions-values.yaml
kubectl rollout restart deployment argocd-server -n argocd
```

### 6) Verify in the UI

Port-forward `argocd-server`, open the UI, and check the **TrustFlow** tab on an Application or Deployment.

## GitHub settings to enforce promotion gates

- Protect `main` and require the `verify-promotion` status check.
- Configure `CODEOWNERS` (see `CODEOWNERS`) + require code owner review for `/environments/prod/`.
