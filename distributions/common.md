# Distribution contract

Every `distributions/<dist>/` directory must satisfy this contract so that the
`platform/` and `apps/` layers remain distribution-agnostic.

## Required files

| File           | Purpose                                                                                                                            |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `bootstrap.sh` | Idempotent. Brings the cluster to a healthy state and writes a kubeconfig to `$KUBECONFIG_PATH` (default `./.kube/<dist>.config`). |
| `teardown.sh`  | Idempotent. Removes the cluster (or returns the substrate to the pre-bootstrap state).                                             |
| `README.md`    | Operator-facing notes: prerequisites, expansion paths, caveats.                                                                    |
| `*.example.*`  | Templates for any operator-supplied configuration. The non-example variants are `.gitignored`.                                     |

## Required behaviour

1. **Idempotent**: re-running `bootstrap.sh` against a healthy cluster must
   succeed without changes (ideally a no-op).
2. **Output kubeconfig**: written to the path in the `KUBECONFIG_PATH` env var,
   or `./.kube/<dist>.config` by default.
3. **Kernel sysctls**: bootstrap is responsible for ensuring each node has the
   multicast prerequisites (see `docs/networking.md`):
   - `net.ipv6.conf.all.disable_ipv6=0`
   - `net.ipv6.conf.<fabric_iface>.disable_ipv6=0`
   - `net.ipv6.conf.all.force_mld_version=2`
   - `net.ipv6.mld_max_msf=<MLD_MAX_MSF, default 1024>` (SSM source-filter cap)
4. **CNI selection**: defer to `$CNI` (default `calico`). The distribution may
   pre-disable a built-in CNI (e.g. k0s ships kube-router by default) when a
   different `$CNI` is chosen.
5. **No coupling** to `platform/` or `apps/`. The platform layer applies addons
   only after `bootstrap.sh` has succeeded.

## Optional files

- `hosts.example.env` — shell-sourced environment with `SSH_USER`, `SSH_KEY`,
  per-node hostnames/IPs.
- Distribution-specific config templates (e.g. `k0sctl.yaml.example`).

## Adding a new distribution

1. Create `distributions/<name>/` and the four required files above.
2. Document any cloud / IaaS prerequisites (IAM, VPC, etc.) in its `README.md`.
3. Verify `make all DIST=<name>` brings the full stack up against an empty
   target.
