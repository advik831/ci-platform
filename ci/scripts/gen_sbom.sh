#!/usr/bin/env bash
set -euo pipefail

# Generate SBOM for promoted image digest. Optional job, manual trigger.
IMAGE_REF=${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHA}
OUTPUT=${SBOM_OUTPUT:-sbom.json}

if [[ -z "${BUILD_IMAGE:-}" ]]; then
  echo "[warn] BUILD_IMAGE not set; skipping SBOM generation"
  exit 0
fi

podman run --rm \
  -v "$PWD:/workspace" \
  -w /workspace \
  "$BUILD_IMAGE" \
  syft "$IMAGE_REF" -o json > "$OUTPUT"

echo "[ok] SBOM written to $OUTPUT"
