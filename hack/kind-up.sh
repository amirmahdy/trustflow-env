#!/usr/bin/env bash
set -euo pipefail

env_name="${1:-dev}"
cluster_name="trustflow"

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 2; }
}

need kubectl
need helm
need kind

ensure_kind_cluster() {
  if ! kind get clusters 2>/dev/null | grep -q "^${cluster_name}$"; then
    kind create cluster --name "$cluster_name" --config "hack/kind-config.yaml"
  fi
}

install_kyverno() {
  helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null
  helm repo update >/dev/null
  helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --set crds.install=true >/dev/null

  kubectl -n kyverno rollout status deploy/kyverno-admission-controller --timeout=180s
  kubectl -n kyverno rollout status deploy/kyverno-background-controller --timeout=180s
  kubectl -n kyverno rollout status deploy/kyverno-cleanup-controller --timeout=180s
  kubectl -n kyverno rollout status deploy/kyverno-reports-controller --timeout=180s

  echo "Waiting for Kyverno webhook service endpoints..."
  for _ in {1..30}; do
    if kubectl -n kyverno get endpoints kyverno-svc -o jsonpath='{.subsets[0].addresses[0].ip}' >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
}

install_argocd() {
  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
  helm repo update >/dev/null

  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

  for cm in argocd-cm argocd-cmd-params-cm; do
    if kubectl -n argocd get configmap "${cm}" >/dev/null 2>&1; then
      kubectl -n argocd label configmap "${cm}" app.kubernetes.io/managed-by=Helm --overwrite >/dev/null
      kubectl -n argocd annotate configmap "${cm}" meta.helm.sh/release-name=argocd --overwrite >/dev/null
      kubectl -n argocd annotate configmap "${cm}" meta.helm.sh/release-namespace=argocd --overwrite >/dev/null
    fi
  done

  helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace -f "argocd/argocd-server-extensions-values.yaml" >/dev/null
  kubectl -n argocd rollout status deploy/argocd-server --timeout=180s

  kubectl apply -f argocd/argocd-proxy-extension.yaml

  kubectl -n argocd create configmap trustflow-extension-override \
    --from-file=extension-trustflow.js=../trustflow-argocd-extension/dist/extension-trustflow.js \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null

  if ! kubectl -n argocd get deploy argocd-server -o jsonpath='{.spec.template.spec.initContainers[*].name}' | grep -q 'extension-trustflow-override'; then
    kubectl -n argocd patch deployment argocd-server --type='json' -p "$(cat <<'EOF'
[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/-",
    "value": {
      "name": "trustflow-extension-override",
      "configMap": {"name": "trustflow-extension-override"}
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/initContainers/-",
    "value": {
      "name": "extension-trustflow-override",
      "image": "quay.io/argoprojlabs/argocd-extension-installer:v0.0.9@sha256:d2b43c18ac1401f579f6d27878f45e253d1e3f30287471ae74e6a4315ceb0611",
      "command": ["sh", "-c"],
      "args": ["cp /override/extension-trustflow.js /tmp/extensions/resources/trustflow/extension-trustflow.js"],
      "volumeMounts": [
        {"name": "extensions", "mountPath": "/tmp/extensions/"},
        {"name": "trustflow-extension-override", "mountPath": "/override"}
      ],
      "securityContext": {"runAsUser": 1000, "allowPrivilegeEscalation": false}
    }
  }
]
EOF
    )" >/dev/null
  fi

  kubectl rollout restart deployment argocd-server -n argocd
  kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
  kubectl -n argocd patch configmap argocd-rbac-cm --type merge \
    -p '{"data":{"policy.csv":"p, role:admin, extensions, invoke, trustflow, allow\n"}}' >/dev/null
}

install_trivy_operator() {
  helm repo add aquasecurity https://aquasecurity.github.io/helm-charts/ >/dev/null
  helm repo update >/dev/null
  helm upgrade --install trivy-operator aquasecurity/trivy-operator -n trivy-system --create-namespace -f trivy/trivy-operator-digests.yaml >/dev/null
  kubectl -n trivy-system rollout status deploy/trivy-operator --timeout=180s
}

apply_policies_and_env() {
  kubectl apply -k policies/kyverno
  kubectl apply -k "environments/${env_name}"
  kubectl -n trustflow rollout status deploy/"${env_name}-trustflow-app" --timeout=180s
}

deploy_verifier() {
  verifier_image="$(awk '/image: .*trustflow-verifier/ {print $2; exit}' argocd/trustflow-verifier.yaml)"
  if [[ -z "${verifier_image}" ]]; then
    echo "ERROR: trustflow-verifier image not found in argocd/trustflow-verifier.yaml"
    exit 2
  fi
  if [[ "${verifier_image}" != *@sha256:* ]]; then
    echo "ERROR: trustflow-verifier image must be pinned by digest (image@sha256:...)."
    exit 2
  fi

  tmp_verifier="$(mktemp)"
  # Escape only replacement metacharacters for the '|' delimiter (avoid introducing literal backslashes).
  escaped_image="$(printf '%s' "${verifier_image}" | sed -e 's/[&|]/\\&/g')"
  sed -e "s|^\\([[:space:]]*image:\).*trustflow-verifier.*$|\\1 ${escaped_image}|" argocd/trustflow-verifier.yaml > "${tmp_verifier}"
  kubectl apply -f "${tmp_verifier}"
  kubectl -n argocd rollout status deploy/trustflow-verifier --timeout=180s
  rm -f "${tmp_verifier}"
}

deploy_trustflow_app() {
  kubectl apply -f argocd/trustflow-app.yaml
}

# --- Kind setup (local cluster) ---
ensure_kind_cluster

# --- Generic cluster setup (kind or any kube context) ---
install_kyverno
install_argocd
install_trivy_operator
apply_policies_and_env
deploy_verifier
deploy_trustflow_app

echo "OK: cluster '${cluster_name}' ready, Argo CD + Trivy installed, Kyverno policies applied, env '${env_name}' deployed."
