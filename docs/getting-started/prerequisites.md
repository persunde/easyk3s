# Prerequisites

Before installing K3S, make sure your server and local machine meet the requirements below.

---

## Server requirements

K3S is intentionally lightweight. A basic single-node cluster runs fine on:

| Resource | Minimum | Recommended (full stack) |
|---|---|---|
| vCPUs | 2 | 4 |
| RAM | 2 GB | 4 GB |
| Disk | 20 GB | 40 GB SSD |
| OS | Ubuntu 22.04 | Ubuntu 22.04 LTS |

!!! tip "VPS providers"
    Any VPS works. Popular choices for self-hosting:

    - **[Hetzner](https://hetzner.com)** - Best value in Europe, CPX21 (~€7/month) is ideal
    - **[DigitalOcean](https://digitalocean.com)** - Simple UI, Droplets from $12/month
    - **[Vultr](https://vultr.com)** - Good global coverage, from $6/month

    A Raspberry Pi 4 (4 GB RAM) also works - K3S runs on ARM.

## Operating system

This guide assumes **Ubuntu 22.04 LTS**. The commands may differ slightly on other distributions, but K3S itself supports any modern Linux with a kernel ≥ 5.3.

Log in to your server via SSH:

```bash
ssh root@YOUR_SERVER_IP
```

Create a non-root user with sudo (skip if you already have one):

```bash
adduser deploy
usermod -aG sudo deploy
su - deploy
```

## Domain name

You need a domain name to get HTTPS certificates from Let's Encrypt. Point an A record at your server's IP before you begin:

```
A  @          YOUR_SERVER_IP   (e.g. example.com)
A  *          YOUR_SERVER_IP   (wildcard - optional but useful)
```

DNS changes can take a few minutes to an hour to propagate. You can check with:

```bash
dig +short whoami.example.com
```

If you don't have a domain yet, you can still follow the first few sections using the server's IP address directly. You'll need a domain by the [HTTPS chapter](../networking/https-letsencrypt.md).

## Firewall

Open the ports K3S and your apps need. If your VPS has a cloud firewall (DigitalOcean, Hetzner, etc.) configure it there too.

```bash
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP (needed for Let's Encrypt HTTP-01 challenge)
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 6443/tcp    # K3S API server (kubectl access)
sudo ufw enable
sudo ufw status
```

For a **multi-node cluster** (server + agent nodes), also open:

```bash
sudo ufw allow 8472/udp    # Flannel VXLAN (pod-to-pod traffic between nodes)
sudo ufw allow 10250/tcp   # Kubelet metrics
sudo ufw allow 51820/udp   # WireGuard (only if using encrypted Flannel)
```

!!! note "Single-node cluster"
    If you're running a single server node (the most common beginner setup), you only need ports 22, 80, 443, and 6443.

## Tools on your local machine

You'll control the cluster from your local machine. Install these before starting:

=== "kubectl"
    ```bash
    # Linux
    curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # macOS (Homebrew)
    brew install kubectl

    # Windows (winget)
    winget install Kubernetes.kubectl
    ```

=== "Helm"
    ```bash
    # Linux / macOS
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # macOS (Homebrew)
    brew install helm

    # Windows (winget)
    winget install Helm.Helm
    ```

Verify both are installed:

```bash
kubectl version --client
helm version
```

---

Once your server is ready and firewall is configured, move on to installing K3S.

[Install K3S :material-arrow-right:](install.md){ .md-button .md-button--primary }
