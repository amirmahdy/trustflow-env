#!/usr/bin/env bash
set -euo pipefail

cluster_name="${KIND_CLUSTER_NAME:-trustflow}"

if ! command -v kind >/dev/null 2>&1; then
  echo "kind is required on PATH" >&2
  exit 2
fi

kind delete cluster --name "$cluster_name"

