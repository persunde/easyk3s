# FAQ

Common questions about K3S and this guide.

---

## K3S basics

### Can I run this on a Raspberry Pi?

Yes. K3S runs on ARM64 and ARMv7. The install script detects the architecture automatically:

```bash
curl -sfL https://get.k3s.io | sh -
```

A Raspberry Pi 4 with 4 GB RAM is sufficient for a basic cluster. The monitoring stack (Prometheus + Grafana) needs ~1 GB RAM on its own, so 4 GB is the practical minimum for the full stack.

### How is K3S different from regular Kubernetes (kubeadm)?

| | K3S | Kubeadm (upstream K8s) |
|---|---|---|
| Install | One script | Multi-step process |
| Binary size | ~100 MB | Multiple large binaries |
| Default storage | SQLite (single-node) | etcd |
| Bundled extras | Traefik, Flannel, CoreDNS | None |
| Production HA | Supported (external DB or embedded etcd) | Supported |
| Certification | CNCF-certified | CNCF-certified |

K3S is a fully compliant Kubernetes distribution - it passes the Kubernetes conformance tests. The differences are in packaging and defaults, not capability.

### K3S vs MicroK8s vs RKE2 vs K0s?

| Distribution | Best for |
|---|---|
| **K3S** | VPS / edge / ARM / beginner-friendly |
| **RKE2** | Enterprise / CIS-hardened / on-prem |
| **MicroK8s** | Ubuntu developer workstations (Snap-based) |
| **K0s** | CI/CD pipelines, embedded Kubernetes |

All are CNCF-conformant. K3S has the simplest install and the largest self-hosting community.

### Do I need a paid cloud server?

No. Any VPS with 2 GB RAM works - typically $5-7/month. The full stack (K3S + Traefik + cert-manager + Longhorn + Prometheus + Loki) needs at least **4 GB RAM** to run comfortably.

Cloud options: Hetzner CX22 (~€4/month), DigitalOcean Droplet ($12/month), Vultr ($6/month), Oracle Cloud Free Tier (always-free ARM instances with 24 GB RAM on the free tier).

---

## Installation and upgrades

### How do I upgrade K3S?

Re-running the install script upgrades K3S in place:

```bash
curl -sfL https://get.k3s.io | sh -
```

The script detects the existing installation and upgrades to the latest stable release. Your workloads continue running during the upgrade.

To upgrade to a specific version:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.31.0+k3s1 sh -
```

### How do I back up my cluster?

**K3S cluster state** (etcd/SQLite):

```bash
# SQLite (default single-node)
sudo cp /var/lib/rancher/k3s/server/db/state.db ~/k3s-backup-$(date +%Y%m%d).db

# Embedded etcd (if you used --cluster-init)
sudo k3s etcd-snapshot save --name backup-$(date +%Y%m%d)
# Snapshots go to /var/lib/rancher/k3s/server/db/snapshots/
```

**Application data** - stored in Longhorn volumes. Configure Longhorn's backup target (S3/B2) in the Longhorn UI.

**Kubernetes manifests** - keep your YAML files in git. The cluster state is reproducible from manifests.

### How do I add more nodes?

Get the server token:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

On each new node:

```bash
curl -sfL https://get.k3s.io | \
  K3S_URL=https://YOUR_SERVER_IP:6443 \
  K3S_TOKEN=YOUR_TOKEN \
  sh -
```

Verify on the server:

```bash
kubectl get nodes
```

---

## Troubleshooting

### My pods are stuck in `Pending`

Common causes:

1. **No matching node** - Check `kubectl describe pod <name>` for the `Events` section. Common messages: "Insufficient memory", "Insufficient cpu"
2. **No default StorageClass** - If the pod has a PVC, check `kubectl get pvc`. If the PVC is also `Pending`, you may not have a StorageClass configured.
3. **Taint/toleration mismatch** - Check node taints: `kubectl describe node | grep Taints`
4. **Image pull failure** - The image name may be wrong or the registry unreachable. Check with `kubectl describe pod <name>`.

### My cert-manager certificates aren't being issued

1. Check the certificate object: `kubectl describe certificate <name> -n <namespace>`
2. Check the CertificateRequest: `kubectl get certificaterequest -n <namespace>`
3. Check cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`
4. Make sure port 80 is reachable from the internet (Let's Encrypt needs to reach your server for HTTP-01 validation)
5. Make sure your DNS A record is pointing at your server's IP

### How do I see what's using the most resources?

```bash
kubectl top nodes          # node-level CPU and memory
kubectl top pods -A        # all pods, sorted by resource usage
```

### How do I get shell access to a running pod?

```bash
kubectl exec -it <pod-name> -- /bin/sh
# or if bash is available:
kubectl exec -it <pod-name> -- /bin/bash
```

### K3S won't start after a server reboot

Check the service logs:

```bash
sudo journalctl -u k3s -n 100
```

Common cause: a previous process didn't shut down cleanly. Try:

```bash
sudo systemctl restart k3s
```

---

## Getting help

- **[K3S documentation](https://docs.k3s.io/)** - the official reference
- **[K3S GitHub issues](https://github.com/k3s-io/k3s/issues)** - bug reports and community questions
- **[Rancher Slack](https://slack.rancher.io/)** - `#k3s` channel
