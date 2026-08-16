# NetworkAttachmentDefinitions (NADs)

Each NAD describes one Multus secondary interface. NADs are rendered with
`envsubst` from the `FABRIC_IFACE` / `BGP_TRANSIT_IFACE` / `BGP_IBGP_IFACE`
environment variables consumed by `scripts/platform-apply.sh` (script-local
defaults apply).

| File | Purpose | Default state |
|---|---|---|
| `mcast-fabric.yaml.gotmpl` | macvlan over the dedicated multicast NIC | applied |
| `bgp-transit.yaml.gotmpl`  | macvlan over the BGP transit NIC (scenarios 40–42) | not applied (excluded from the default `NADS` set; add via `NADS=` env var) |
| `bgp-ibgp.yaml.gotmpl`     | macvlan over the BGP iBGP NIC | not applied |
| `mcast-vf.yaml.gotmpl`     | SR-IOV VF from the device-plugin pool (zero-copy AF_XDP path) | applied only when `ENABLE_SRIOV=true` |

## Adding new NADs

1. Drop a `<name>.yaml.gotmpl` here using the same `${FABRIC_IFACE}` convention.
2. Reference it from `platform-apply.sh` (or pass via `NADS=` env var).

The chart-side `networking.multus.networkName` value must match the NAD's
`metadata.name`.
