# Install K3S

K3S installs as a single binary with a systemd service. The entire installation is one command.

---

## What K3S installs by default

When you run the install script, K3S sets up a fully functional Kubernetes cluster including:

| Component | Purpose |
|---|---|
| **Traefik** | Ingress controller - routes external HTTP/HTTPS traffic to your pods |
| **Flannel** | CNI - handles pod-to-pod networking across nodes |
| **CoreDNS** | In-cluster DNS - lets pods find each other by name |
| **local-path-provisioner** | Automatic PersistentVolumes backed by the host filesystem |
| **metrics-server** | Enables `kubectl top nodes/pods` |

You don't need to install any of these separately.

---

## Install (single node)

SSH into your server and run:

```bash
curl -sfL https://get.k3s.io | sh -
```

That's it. K3S downloads, installs, and starts as a systemd service.

### Recommended: install with your domain name as a TLS SAN

If you plan to access the K3S API from outside the server (which you do - you'll use kubectl from your laptop), add your server's domain or IP as a Subject Alternative Name so the API certificate is valid:

```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --tls-san=YOUR_DOMAIN_OR_IP \
  --write-kubeconfig-mode=644
```

Replace `YOUR_DOMAIN_OR_IP` with either your domain (e.g. `k3s.example.com`) or your server's public IP. You can pass `--tls-san` multiple times if you want both:

```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --tls-san=k3s.example.com \
  --tls-san=203.0.113.10 \
  --write-kubeconfig-mode=644
```

---

## Verify the installation

Check that the K3S service is running:

```bash
sudo systemctl status k3s
```

You should see `active (running)`. Then verify the node is ready:

```bash
sudo k3s kubectl get nodes
```

Expected output:

```
NAME        STATUS   ROLES                  AGE   VERSION
my-server   Ready    control-plane,master   30s   v1.31.x+k3s1
```

Check that the default pods are running:

```bash
sudo k3s kubectl get pods --all-namespaces
```

After a minute or two, everything should be `Running` or `Completed`.

---

## Configuration file (alternative to flags)

Instead of passing flags on the command line, you can create a config file before installing:

```bash
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml <<EOF
tls-san:
  - YOUR_DOMAIN_OR_IP
write-kubeconfig-mode: "644"
EOF
```

Then run the simple install:

```bash
curl -sfL https://get.k3s.io | sh -
```

The config file approach is easier to maintain and version-control.

Read more about the [K3S configuration file](https://docs.k3s.io/installation/configuration#configuration-file).

---

## Adding agent nodes (optional)

If you want to add worker nodes to your cluster later:

**On the server**, get the node token:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

**On each agent node**, run:

```bash
curl -sfL https://get.k3s.io | \
  K3S_URL=https://YOUR_SERVER_IP:6443 \
  K3S_TOKEN=YOUR_NODE_TOKEN \
  sh -
```

The agent will join the cluster automatically. Verify with `kubectl get nodes` on the server.

---

## Upgrade K3S

Re-running the install script updates K3S in place:

```bash
curl -sfL https://get.k3s.io | sh -
```

K3S respects your existing configuration during upgrades.

---

## Uninstall

If you need to start over:

```bash
# Server node
/usr/local/bin/k3s-uninstall.sh

# Agent node
/usr/local/bin/k3s-agent-uninstall.sh
```

!!! warning
    Uninstalling removes the cluster, all running pods, and all local storage. Back up any persistent data first.

---

[Initial Setup - configure kubectl :material-arrow-right:](initial-setup.md){ .md-button .md-button--primary }
