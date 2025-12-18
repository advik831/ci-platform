# ci-platform

Production-ready GitLab Ultimate (self-managed 18.5.x) DevSecOps blueprints for air-gapped Kubernetes runners using Podman (vfs).

Contents in this policy project:
- `policy.yml` and `ci/` directory for Scan Execution + Pipeline Execution policies and helper scripts.
- `gitlab-ci.image-repo.yml` for containerized apps and `gitlab-ci.non-image-repo.yml` for non-image repositories.
- `images.txt` list of analyzer/tooling images to mirror into the private registry.

## Air-gap variables
Set these as **masked + protected group variables** (scope: all projects using the policy project):

- `SECURE_ANALYZERS_PREFIX=<private-reg>/gitlab-secure` – rewrites all built-in Secure templates to pull analyzers from the mirror.
- `CS_ANALYZER_IMAGE=<private-reg>/gitlab-secure/container-scanning:<pin-or-digest>` – overrides the analyzer image used by the Container Scanning template.
- `POLICY_TOOLS_IMAGE=<private-reg>/platform/policy-tools:<pin-or-digest>` – contains opa, python, jq for gates.
- `PODMAN_IMAGE=<private-reg>/platform/podman-builder:<pin-or-digest>` – podman/Buildah with `vfs` storage driver enabled.
- `COSIGN_IMAGE=<private-reg>/platform/cosign:<pin-or-digest>` – cosign for signing/attestations.
- `BUILD_IMAGE=<private-reg>/platform/build-<lang>:<pin>` – language-specific build image (per project).
- `COSIGN_PRIVATE_KEY` (+ optional `COSIGN_PASSWORD`) – key material for offline signing; set as masked + protected.

`SECURE_ANALYZERS_PREFIX` automatically rewrites analyzer pulls in SAST/Secrets/Dependency/IaC scanning templates. `CS_ANALYZER_IMAGE` is passed to the Container Scanning job to force the mirrored analyzer. The build job emits `CS_IMAGE` via a dotenv artifact so the Container Scanning job consumes the quarantine tag without manual wiring.

## Policy deployment (Policy Project)
1. Create a dedicated policy project and add this repository content.
2. In GitLab UI: **Security & Compliance → Policies → Import YAML** and paste `policy.yml`.
3. Link the policy project to target groups/projects (Security settings → Policy Management Project).
4. Verify pipelines include injected jobs: `preflight:check_variables`, `opa_shell_gate`, `security:severity_gate`, `image:promote`, `image:sign` (only when `BUILD_IMAGE_ENABLED=true`).

## Pipeline expectations
- **Merge Requests / feature branches:** Secure scans run (soft-fail). Findings appear in MR widgets. Promotion/signing is skipped.
- **Default branch:** Severity gate blocks High/Critical. Container flow = build → push `:ci-$CI_COMMIT_SHA` → container scan → promote by digest → cosign sign → optional SBOM/provenance.
- **Non-image repos:** set `BUILD_IMAGE_ENABLED=false` (default in `gitlab-ci.non-image-repo.yml`) to auto-skip image stages while still running Secure scans via policies.

## Repository hosting
This blueprint has not been pushed to any remote from this workspace. To publish it to GitHub, create an empty repository (or set an existing one) as the `origin` remote and push the current branch:

```bash
git remote add origin git@github.com:<org>/<repo>.git
git push -u origin work
```

Replace `<org>/<repo>` with your GitHub path. Use `git remote -v` afterward to confirm the remote configuration.

## Local sanity checks
These quick checks help confirm the helper scripts are syntactically valid before importing into a policy project:

- `python -m py_compile ci/scripts/security_gate.py` – validates the Python gate script.
- `opa fmt ci/rego/image_hardening.rego` – optional formatting/parse check if `opa` is available locally.
