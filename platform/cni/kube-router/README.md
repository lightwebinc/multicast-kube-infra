# kube-router CNI

kube-router is bundled with k0s. There is no Helm install for this option;
selecting it disables the Calico/Cilium releases.

## Enabling

1. In `distributions/k0s/k0s-config.yaml`, set:
   ```yaml
   spec:
     network:
       provider: kuberouter
   ```
2. Run `make platform CNI=kube-router`. The platform Helmfile applies Multus
   and ESO only; no CNI release is created.

## Limitations vs. Calico / Cilium

- Less mature BGP support; OK for simple route reflection but lacks Calico's
  BGPPeer CR ergonomics.
- No eBPF dataplane (vs. Cilium).

For the multicast workload pods, the fabric data path runs over Multus macvlan
regardless of primary CNI choice; kube-router is sufficient for control and
metrics traffic.
