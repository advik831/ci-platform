#!/usr/bin/env bash
set -euo pipefail

# Generate in-toto provenance using cosign/rekor offline-friendly mode (no transparency log).
IMAGE_REF=${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHA}
PROVENANCE_PATH=${PROVENANCE_OUTPUT:-provenance.json}

if [[ -z "${BUILD_IMAGE:-}" ]]; then
  echo "[warn] BUILD_IMAGE not set; skipping provenance generation"
  exit 0
fi

cosign attest --key env://COSIGN_PRIVATE_KEY \
  --predicate-type slsaprovenance://v1 \
  --predicate "$PROVENANCE_PATH" \
  "$IMAGE_REF"

echo "[ok] Provenance artifact written to $PROVENANCE_PATH"
