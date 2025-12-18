#!/usr/bin/env bash
set -euo pipefail

# Evaluate Rego policy for image hardening. If metadata is missing, do not block pipeline.
INPUT_FILE="image_metadata.json"
REGO_POLICY="ci/rego/image_hardening.rego"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "[info] No image metadata found; skipping OPA shell gate"
  exit 0
fi

if ! command -v opa >/dev/null 2>&1; then
  echo "[warn] opa binary not found in POLICY_TOOLS_IMAGE; skipping gate"
  exit 0
fi

set +e
result=$(opa eval -i "$INPUT_FILE" -d "$REGO_POLICY" 'data.gitlab.policy.image_hardening.violation')
status=$?
set -e

echo "$result"

if [[ $status -ne 0 ]]; then
  echo "[error] opa evaluation failed"
  exit 1
fi

if echo "$result" | grep -q '\[\]'; then
  echo "[ok] No OPA violations"
  exit 0
fi

if echo "$result" | grep -qi "image"; then
  echo "[fail] OPA gate failed"
  exit 1
fi

echo "[ok] OPA evaluation clean"
