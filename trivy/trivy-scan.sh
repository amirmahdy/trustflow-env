#!/usr/bin/env bash
set -euo pipefail

root="environments"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
extract_script="${script_dir}/../scripts/extract-images.sh"

trivy_image="aquasec/trivy:latest"
default_threshold="HIGH"

if [[ ! -d "${root}" ]]; then
  echo "Environment root not found: ${root}" >&2
  exit 2
fi

severity_for_threshold() {
  local threshold="${1^^}"
  case "${threshold}" in
    CRITICAL) echo "CRITICAL" ;;
    HIGH) echo "HIGH,CRITICAL" ;;
    MEDIUM) echo "MEDIUM,HIGH,CRITICAL" ;;
    LOW) echo "LOW,MEDIUM,HIGH,CRITICAL" ;;
    UNKNOWN) echo "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL" ;;
    *)
      echo "Unsupported Trivy threshold: ${threshold}" >&2
      return 2
      ;;
  esac
}

scan_env_dir() {
  local env_dir="$1"
  local env_name
  local threshold_var
  local threshold
  local severities

  env_name="$(basename "${env_dir}")"
  threshold_var="TRIVY_THRESHOLD_${env_name^^}"
  threshold="${!threshold_var:-${default_threshold}}"
  threshold="${threshold^^}"

  severities="$(severity_for_threshold "${threshold}")"

  mapfile -t images < <(bash "${extract_script}" "${env_dir}")
  if [[ ${#images[@]} -eq 0 ]]; then
    echo "No pinned images found under: ${env_dir} (skipping)"
    return 0
  fi

  for image in "${images[@]}"; do
    echo "Trivy scan (${env_name}, threshold ${threshold}): ${image}"
    docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      "${trivy_image}" \
      image \
      --severity "${severities}" \
      --exit-code 1 \
      --ignore-unfixed \
      --format table \
      "${image}"
  done
}

found_env=false
for env_dir in "${root}"/*; do
  [[ -d "${env_dir}" ]] || continue
  found_env=true
  scan_env_dir "${env_dir}"
done

if [[ "${found_env}" == false ]]; then
  echo "No environments found under: ${root}" >&2
  exit 2
fi
