# Networking

## Two-layer model

| Layer | Carries | Implementation |
|---|---|---|
| Primary CNI         | control + metrics + NACK/ACK + beacons (over IPv6 unicast) | Calico / Cilium / kube-router |
| Multus secondary `net1` | IPv6 multicast frame data plane | macvlan over the dedicated fabric NIC |

Pod annotation:

```yaml
metadata:
  annotations:
    k8s.v1.cni.cncf.io/networks: |
      [{ "name": "mcast-fabric", "interface": "net1",
         "ips": ["fd20::21/64"] }]
```

The chart's `networking.mode: multus` value renders this annotation
automatically; chart-side env (`MULTICAST_IF=net1`) is wired in lockstep.

## CNI choices

```bash
make platform CNI=calico       # default; Calico via tigera-operator
make platform CNI=cilium       # eBPF dataplane, native BGP control plane
make platform CNI=kube-router  # k0s-bundled; no Helm install
```

For BGP-aware deployments (peering pods/Service CIDRs into a fabric router):

- **Calico**: enable `bgp` in `platform/environments/default.yaml`, then apply
  `BGPPeer` CRs separately. Calico's BGP runs on the **primary CNI** NIC, not
  the multicast NIC.
- **Cilium**: set `bgp.enabled=true` and apply `CiliumBGPPeeringPolicy` CRs.

The dedicated multicast NIC is reserved exclusively for the multicast fabric
data plane. Do not run BGP over it.

## NetworkAttachmentDefinitions (NADs)

Templates live under `platform/nads/`. `scripts/platform-apply.sh` reads the
`NADS` env var to decide which to apply (default `mcast-fabric` only). Add
others on the command line:

```bash
NADS=mcast-fabric,bgp-transit,bgp-ibgp \
  BGP_TRANSIT_IFACE=enp6s0 BGP_IBGP_IFACE=enp7s0 \
  scripts/platform-apply.sh
```

## Kernel sysctls

Each k0s worker that joins multicast groups needs:

```
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.<fabric_iface>.disable_ipv6 = 0
net.ipv6.conf.all.force_mld_version = 2
```

`distributions/k0s/bootstrap.sh` applies these via SSH and persists them under
`/etc/sysctl.d/80-bsv-mcast.conf`.

### SSM source-filter limits (required when `sourceMode=ssm`)

Source-Specific Multicast (RFC 4607) — used by Posture B/C/D in the
[SSM Support Plan](https://github.com/lightwebinc/bsv-multicast/blob/main/DESIGN.md#source-specific-multicast-ssm) —
relies on `MCAST_JOIN_SOURCE_GROUP` (RFC 3678). The Linux default cap of
**64 source filters per socket** is below the production fleet size; with
hundreds of publishers a fresh join returns `ENOBUFS`. Raise it on every
worker that runs a listener / retry-endpoint:

```
net.ipv6.mld_max_msf = 1024
```

Pick the value as `≥ 2 × N_publishers` to leave headroom for fleet
growth and transient overlap during proxy rollouts.
`distributions/k0s/bootstrap.sh` adds this line alongside the existing
sysctls when the operator selects SSM at provision time.

### PIM-SSM in the fabric

When any deployment opts into `sourceMode=ssm` the upstream router MUST
enable PIM-SSM on the `FF3x::/32` range:

- **Posture B** (data-plane SSM, ASM control groups): PIM-SSM and
  PIM-SM (with an RP) coexist on the fabric. MLDv2 mandatory.
- **Posture C** (SSM-everywhere intra-domain): PIM-SSM only. **No RP,
  no PIM-SM, no MSDP.** This is the recommended steady state — the
  fabric config shrinks to "enable PIM-SSM on FF3x::/32, enforce
  MLDv2".
- **Posture D** (SSM inter-domain): PIM-SSM peering across
  administrative domains. The only RFC 8815-compliant inter-domain
  configuration.

The control-group SSM joins use small per-group bootstrap lists (DNS
names or IPv6 literals — typically headless-Service names fronting the
relevant control-plane pods). See the SSM Support Plan for the per-list
sizing and DNS-resolution semantics.

### Deterministic per-pod IPv6 (Multus static IPAM)

Posture B/C/D require each shard-proxy / shard-manifest / retry-endpoint
replica to bind a **distinct, stable IPv6** (anycast across replicas
breaks PIM-SSM RPF). Pod IPs from the default CNI are ephemeral; the
NADs in `platform/nads/` use static IPAM (`"ipam": { "type": "static" }`),
and each release supplies its fabric address via the chart's
`networking.multus.fabricIPv6` value, rendered into the pod's
`k8s.v1.cni.cncf.io/networks` annotation (see `apps/values/*.yaml.gotmpl`).
The Helm charts surface `bindSource` (proxy / retry-endpoint; the
manifest chart models publishers via `manifest.publishers`)
and `ssmBootstrap.*` lists (listener / retry-endpoint) — set
`bindSource` to the same per-release fabric IPv6.

`hostNetwork: true` is the fallback when Multus is unavailable but
couples component identity to node identity. A normal Kubernetes
`Service` does **not** solve this — it allocates a unicast VIP, not an
interface address.

## NACK source-address pitfall

The retry endpoint must bind its NACK socket to the **same** IPv6 the listener
addresses it by, otherwise SLAAC source-address selection causes ACKs to be
silently dropped (see the upstream
[`retry-endpoint` README](https://github.com/lightwebinc/retry-endpoint)).
The chart pattern enforced by `apps/helmfile.yaml.gotmpl` sets `config.nackAddr`
explicitly per release — do not leave it empty.

## Cloud-friendly fallback (no multicast)

Proxy unicast egress is **not implemented** — the proxy emits multicast only,
so the emitting side of the stack needs an IPv6-multicast-capable data plane
(Multus macvlan or `hostNetwork` on a real fabric NIC). The shipped
no-multicast path is the listener's delivery mode (chart
`config.mode: delivery`, shard-listener v1.6.9+): a delivery-mode listener
ingests frames over unicast from an upstream receiver-mode listener and fans
out to consumers, so consumer-facing clusters can run on a standard CNI and
skip the Multus and NADs releases. A proxy-side unicast egress mode remains
an open design item.

## Cache backends (Redis / Aerospike)

The proxy/listener dedup gates and the retry-endpoint frame cache use the
modular `shard-common/cache` backend, selected per-chart (`config.txidDedup.backend`,
`config.egressDedupBackend` / `config.ingressSetBackend`, `config.cacheBackend`).
Deploy the backend as a separate in-cluster workload (e.g. a Redis/Valkey
StatefulSet, or an Aerospike Community Edition StatefulSet) on the pod network
and point the chart values at its Service DNS name. Aerospike needs a
provisioned namespace and uses whole-second TTLs (floor 1s). Backend errors fail
open. See
[shard-common cache backend](https://github.com/lightwebinc/shard-common/blob/main/docs/cache-backend.md).
