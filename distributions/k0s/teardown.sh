#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${HERE}"

[[ -f k0sctl.yaml ]] || { echo "no k0sctl.yaml; nothing to tear down"; exit 0; }

echo "==> k0sctl reset (will uninstall k0s on every host)"
k0sctl reset --config k0sctl.yaml --force
