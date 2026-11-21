# Troubleshooting

## bootstrap.sh

| Symptom | Likely cause | Fix |
|---|---|---|
| `permission denied (publickey)` | `SSH_KEY` not loaded | Ensure `ssh-add` or correct `SSH_KEY` in `hosts.env` (rendered into `keyPath`). |
| `k0sctl: cannot find binary` | `k0sctl` missing from `$PATH` | Install from https://github.com/k0sproject/k0sctl/releases. |
| Kubeconfig empty after fetch | `k0sctl apply` partially failed | Check `~/.k0sctl/log.txt`; re-run after fix. |

## Platform

| Symptom | Likely cause | Fix |
|---|---|---|
| Calico pods CrashLoopBackOff | `provider: kuberouter` left in `k0s-config.yaml` | Set `provider: custom`, re-bootstrap. |
| Multus DaemonSet not Ready | k0s CNI dir mismatch on FreeBSD | k0s + Multus only validated on Linux today. |
| `NetworkAttachmentDefinition not found` | NAD applied in wrong namespace | NADs live in `bsv-mcast`; chart annotation references `namespace: bsv-mcast`. |

## Applications

| Symptom | Likely cause | Fix |
|---|---|---|
| Listener receives 0 frames | MLD not joined on `net1` | Check `force_mld_version=2` sysctl on the node; verify NAD `master:` matches the real NIC name. |
| Listener counts each frame twice | `numWorkers > 1` (SO_REUSEPORT mcast duplication) | Chart hardcodes `numWorkers=1`; do not override. |
| Retry endpoint logs "invalid NACK size" | Listener and retry built from incompatible commits | Bump chart `appVersion` in lockstep across all four charts. |
| Listener never receives ACKs | `nackAddr` empty or wrong on retry endpoint | Set `config.nackAddr` per-release to the exact IPv6 listed in `RETRY_ENDPOINTS`. |

## Helm/Helmfile

| Symptom | Likely cause | Fix |
|---|---|---|
| `chart not found in repository` | OCI registry not authenticated | `helm registry login ghcr.io` first; check chart version. |
| `helmfile diff` reports phantom drift | Default values changed upstream | Bump `chartVersions.*` and re-`apply`. |

## Gathering logs

```bash
kubectl -n bsv-mcast logs -l app.kubernetes.io/name=shard-listener --tail=200
kubectl -n bsv-mcast describe pod -l app.kubernetes.io/name=shard-proxy
kubectl -n kube-system logs -l app=multus
```
