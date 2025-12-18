#!/usr/bin/env python3
"""Branch-aware security gating utility.

Functions:
- --check-required-vars: ensure mandatory variables are present for default branch.
- --severity-threshold <level>: parse GitLab JSON security reports and fail if High/Critical exceed threshold.

The parser expects GitLab Secure report files in the working directory (default artifact names):
  gl-sast-report.json
  gl-dependency-scanning-report.json
  gl-secret-detection-report.json
  gl-sast-iac-report.json
  gl-container-scanning-report.json
"""

import argparse
import json
import os
from pathlib import Path
from typing import Dict, List

REPORT_FILES = [
    "gl-sast-report.json",
    "gl-dependency-scanning-report.json",
    "gl-secret-detection-report.json",
    "gl-sast-iac-report.json",
    "gl-container-scanning-report.json",
]

REQUIRED_VARS = [
    "SECURE_ANALYZERS_PREFIX",
    "POLICY_TOOLS_IMAGE",
    "PODMAN_IMAGE",
    "COSIGN_IMAGE",
]

SEVERITY_ORDER = ["info", "unknown", "low", "medium", "high", "critical"]


def load_findings(files: List[str]) -> List[Dict]:
    findings: List[Dict] = []
    for file_name in files:
        path = Path(file_name)
        if not path.exists():
            continue
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError:
            print(f"[warn] Could not parse {file_name}")
            continue
        for vuln in data.get("vulnerabilities", []):
            findings.append(vuln)
    return findings


def severity_exceeds(findings: List[Dict], threshold: str) -> bool:
    threshold_index = SEVERITY_ORDER.index(threshold)
    for vuln in findings:
        severity = vuln.get("severity", "unknown").lower()
        if severity not in SEVERITY_ORDER:
            continue
        if SEVERITY_ORDER.index(severity) >= threshold_index:
            print(f"[gate] Found {severity} vulnerability: {vuln.get('name', 'unknown')} (id={vuln.get('id')})")
            return True
    return False


def check_required_vars() -> int:
    missing = [env for env in REQUIRED_VARS if not os.environ.get(env)]
    if missing:
        print(f"[error] Missing required variables: {', '.join(missing)}")
        return 1
    print("[ok] All required variables present for default-branch enforcement")
    return 0


def run_threshold_check(threshold: str, enforce_default: bool) -> int:
    is_default_branch = os.environ.get("CI_COMMIT_BRANCH") == os.environ.get("CI_DEFAULT_BRANCH")
    findings = load_findings(REPORT_FILES)
    if not findings:
        print("[info] No report files found; allowing pipeline to continue")
        return 0

    exceeds = severity_exceeds(findings, threshold)
    if exceeds and (not enforce_default or is_default_branch):
        print(f"[fail] Severity threshold '{threshold}' exceeded")
        return 1
    if exceeds:
        print(f"[warn] Threshold exceeded but branch is not default ({os.environ.get('CI_COMMIT_BRANCH')}); soft fail allowed")
    else:
        print(f"[ok] No findings above {threshold}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Security gate helper")
    parser.add_argument("--check-required-vars", action="store_true", help="Validate required protected variables")
    parser.add_argument("--severity-threshold", choices=SEVERITY_ORDER, help="Severity threshold to enforce")
    parser.add_argument("--enforce-default-branch", action="store_true", help="Only fail when running on default branch")
    args = parser.parse_args()

    if args.check_required_vars:
        return check_required_vars()

    if args.severity_threshold:
        return run_threshold_check(args.severity_threshold, args.enforce_default_branch)

    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
