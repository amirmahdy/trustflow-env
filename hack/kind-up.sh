#!/usr/bin/env bash
set -euo pipefail

env_name="${1:-dev}"
cluster_name="${KIND_CLUSTER_NAME:-trustflow}"

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 2; }
}

need kind
need kubectl
need helm

kind create cluster --name "$cluster_name" --config "$(dirname "$0")/kind-config.yaml"

helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null
helm repo update >/dev/null
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --set crds.install=true >/dev/null

kubectl -n kyverno rollout status deploy/kyverno-admission-controller --timeout=180s
kubectl -n kyverno rollout status deploy/kyverno-background-controller --timeout=180s
kubectl -n kyverno rollout status deploy/kyverno-cleanup-controller --timeout=180s
kubectl -n kyverno rollout status deploy/kyverno-reports-controller --timeout=180s

kubectl apply -k policies/kyverno
kubectl apply -k "environments/${env_name}"

echo "OK: kind cluster '${cluster_name}' ready, Kyverno policies applied, env '${env_name}' deployed."

