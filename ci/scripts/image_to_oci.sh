#!/usr/bin/env bash
set -euo pipefail

COMMAND=${1:-}

if [[ -z "$COMMAND" ]]; then
  echo "usage: $0 <promote|sign>"
  exit 1
fi

# Ensure Podman uses vfs for Kubernetes compatibility
export STORAGE_DRIVER=${STORAGE_DRIVER:-vfs}
export BUILDAH_FORMAT=docker

REGISTRY_IMAGE=${CI_REGISTRY_IMAGE:-}
if [[ -z "$REGISTRY_IMAGE" ]]; then
  echo "[error] CI_REGISTRY_IMAGE is required"
  exit 1
fi

QUARANTINE_TAG=${CI_REGISTRY_IMAGE}:ci-${CI_COMMIT_SHA}
RELEASE_TAG=${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHA}
LATEST_TAG=${CI_REGISTRY_IMAGE}:latest

promote() {
  CS_IMAGE=${CS_IMAGE:-$QUARANTINE_TAG}
  echo "[info] Inspecting quarantine image $CS_IMAGE"
  DIGEST=$(podman image inspect --format '{{.Digest}}' "$CS_IMAGE")
  if [[ -z "$DIGEST" ]]; then
    echo "[error] Unable to read image digest"
    exit 1
  fi
  echo "[info] Promoting digest $DIGEST to $RELEASE_TAG"
  podman tag "$CS_IMAGE@$DIGEST" "$RELEASE_TAG"
  podman push "$RELEASE_TAG"
  if [[ "${PUSH_LATEST:-false}" == "true" ]]; then
    echo "[info] Also tagging latest"
    podman tag "$CS_IMAGE@$DIGEST" "$LATEST_TAG"
    podman push "$LATEST_TAG"
  fi
  echo "IMAGE_DIGEST=$DIGEST" > promotion.env
}

sign() {
  if [[ -z "${COSIGN_PRIVATE_KEY:-}" ]]; then
    echo "[error] COSIGN_PRIVATE_KEY not provided"
    exit 1
  fi
  DIGEST=${IMAGE_DIGEST:-$(podman image inspect --format '{{.Digest}}' "$RELEASE_TAG")}
  if [[ -z "$DIGEST" ]]; then
    echo "[error] Missing digest for signing"
    exit 1
  fi
  echo "[info] Signing $RELEASE_TAG@$DIGEST"
  COSIGN_PASSWORD=${COSIGN_PASSWORD:-""} cosign sign --key env://COSIGN_PRIVATE_KEY "$RELEASE_TAG@$DIGEST"
}

case "$COMMAND" in
  promote)
    promote
    ;;
  sign)
    sign
    ;;
  *)
    echo "unknown command $COMMAND"
    exit 1
    ;;
esac
