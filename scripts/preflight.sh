#!/usr/bin/env bash
# Preflight checks: tools present, hosts reachable.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${HERE}/.." && pwd)"
DIST="${DIST:-k0s}"

fail=0
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing: $1" >&2
    fail=1
  fi
}

echo "==> tool versions"
need k0sctl
need kubectl
need helm
need helmfile
need envsubst
need ssh

if [[ "${DIST}" == "k0s" ]]; then
  hosts_env="${ROOT}/distributions/k0s/hosts.env"
  if [[ ! -f "${hosts_env}" ]]; then
    echo "missing: ${hosts_env} (copy from hosts.example.env)" >&2
    fail=1
  else
    # shellcheck disable=SC1090
    source "${hosts_env}"
    echo "==> ssh reachability"
    for var in NODE0_ADDR NODE1_ADDR NODE2_ADDR; do
      addr="${!var:-}"
      [[ -z "${addr}" ]] && continue
      if ssh -i "${SSH_KEY}" -o BatchMode=yes -o ConnectTimeout=5 \
            "${SSH_USER}@${addr}" 'true' 2>/dev/null; then
        echo "  ok: ${addr}"
      else
        echo "  FAIL: ${addr}" >&2
        fail=1
      fi
    done
  fi
fi

if [[ ${fail} -ne 0 ]]; then
  echo "preflight failed" >&2
  exit 1
fi
echo "==> preflight ok"
