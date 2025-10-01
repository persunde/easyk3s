# EasyK3S

**A hands-on guide to running your own Kubernetes cluster - without the enterprise complexity.**

---

!!! tip "Who is this for?"
    This guide is for **developers who are new to Kubernetes** and want to set up a real, self-managed cluster from scratch. We use [K3S](https://k3s.io/). It is a lightweight Kubernetes distribution that runs on a single $5/month VPS and fits in under 100 MB. By the end, you will have a production-worthy cluster with HTTPS, monitoring, logging, persistent storage, and auto-healing.

## What is K3S?

K3S is a certified Kubernetes distribution from Rancher (now part of SUSE). It packages everything you need into a single binary:

- **Traefik** - Ingress controller and reverse proxy
- **Flannel** - Pod networking (CNI)
- **CoreDNS** - In-cluster DNS
- **local-path-provisioner** - Simple persistent volumes
- **metrics-server** - Resource usage metrics

That means you get a working Kubernetes cluster with one `curl` command. No kubeadm, no complex multi-step bootstrap, no cloud provider required.

## What you'll build

By following this guide in order, you'll go from a fresh Ubuntu VM to a fully operational cluster:

1. **Install K3S** on a VPS - one command, under two minutes
2. **Configure kubectl** on your local machine and tour the cluster
3. **Deploy your first app** - a Hello World exposed over HTTP
4. **Set up Traefik** - the built-in ingress controller, with its dashboard
5. **Enable HTTPS** - automatic TLS certificates via Let's Encrypt and cert-manager
6. **Add authentication** - protect dashboards with Basic Auth
7. **Set up persistent storage** - Longhorn distributed block storage
8. **Add metrics** - Prometheus + Grafana via kube-prometheus-stack
9. **Add logging** - Loki + Promtail, integrated into Grafana
10. **Understand auto-healing** - how Kubernetes keeps your apps running
11. **Run PostgreSQL** - pointer to CloudNativePG for production databases

## What you need before starting

| Requirement | Minimum | Recommended |
|---|---|---|
| vCPUs | 2 | 4 |
| RAM | 2 GB | 4 GB |
| Disk | 20 GB | 40 GB |
| OS | Ubuntu 22.04 | Ubuntu 22.04 LTS |
| Domain name | Required (for HTTPS) | - |
| Time | ~2 hours | - |

Any VPS will work - [Hetzner](https://hetzner.com), [DigitalOcean](https://digitalocean.com), [Vultr](https://vultr.com), or your own hardware.

!!! warning "This is not managed Kubernetes"
    K3S is **self-managed**. You handle upgrades, backups, and failures. This is meant to help you learn and to understand the basics of Kubernetes. For production workloads with SLA requirements, consider managed Kubernetes (EKS, GKE, AKS).

## Ready? Start here

[Get started with Prerequisites :material-arrow-right:](getting-started/prerequisites.md){ .md-button .md-button--primary }
