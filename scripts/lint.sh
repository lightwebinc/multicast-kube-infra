#!/usr/bin/env bash
# Static lint pass. Does not require a live cluster.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${HERE}/.." && pwd)"
cd "${ROOT}"

ok=0
fail() { echo "FAIL: $*" >&2; ok=1; }

echo "==> shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  # SC1091: source paths only resolvable at runtime.
  # SC2086: word-splitting is intentional for argv-style variables.
  # SC2153: NODE{0,1,2}_ADDR are sourced at runtime from hosts.env (gitignored).
  shellcheck -e SC1091 -e SC2086 -e SC2153 \
    distributions/k0s/bootstrap.sh \
    distributions/k0s/teardown.sh  \
    scripts/*.sh || fail shellcheck
else
  echo "  (shellcheck not installed — skipping)"
fi

echo "==> yamllint"
if command -v yamllint >/dev/null 2>&1; then
  # Helmfile gotmpl files are not pure YAML; exclude them.
  yamllint -d '{extends: default, rules: {line-length: disable, document-start: disable, indentation: {spaces: 2, indent-sequences: consistent}}}' \
    platform/namespaces.yaml \
    platform/secrets/cluster-secret-store.example.yaml \
    apps/environments/default.yaml \
    apps/environments/reference-k0s.yaml \
    apps/environments/production.yaml.example \
    distributions/k0s/k0s-config.yaml.example \
    || fail yamllint
else
  echo "  (yamllint not installed — skipping)"
fi

echo "==> helmfile lint (platform)"
if command -v helmfile >/dev/null 2>&1; then
  helmfile -f platform/helmfile.yaml lint || fail "helmfile platform"
else
  echo "  (helmfile not installed — skipping)"
fi

echo "==> helmfile lint (apps — best-effort; requires published OCI charts)"
if command -v helmfile >/dev/null 2>&1; then
  # Apps charts are OCI artifacts published by the *-helm release pipelines.
  # This step is best-effort: it validates values + templates when charts are
  # available, but does not fail the lint job if they have not been published yet.
  helmfile -f apps/helmfile.yaml.gotmpl -e reference-k0s lint \
    || echo "  WARN: helmfile apps lint failed (OCI charts not yet published — skipping)"
else
  echo "  (helmfile not installed — skipping)"
fi

if [[ ${ok} -ne 0 ]]; then exit 1; fi
echo "==> lint ok"
