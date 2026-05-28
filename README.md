# EasyK3S

A hands-on guide to running your own Kubernetes cluster without the enterprise complexity.

Live site: **[easyk3s.dev](https://easyk3s.dev/)**

---

## What is this?

EasyK3S is a documentation site for developers who are new to Kubernetes and want to set up a real, self-managed cluster from scratch using [K3S](https://k3s.io/). It walks you through going from a fresh Ubuntu VPS to a production-worthy cluster with HTTPS, monitoring, logging, persistent storage, and auto-healing.

The guide covers:

- Installing K3S and configuring kubectl
- Deploying apps and setting up Traefik ingress
- Automatic TLS certificates via cert-manager + Let's Encrypt
- Persistent storage with Longhorn
- Metrics with Prometheus + Grafana
- Logging with Loki + Promtail
- Running PostgreSQL with CloudNativePG

## Tech stack

The site is built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/).

## Running locally

```bash
pip install -r requirements.txt
mkdocs serve
```

Then open [http://localhost:8000](http://localhost:8000).

## Contributing

Contributions are welcome, typo fixes, clarifications, new examples, or additional sections.

1. Fork the repo and create a branch
2. Edit or add Markdown files under `docs/`
3. Register new pages in `mkdocs.yml` under `nav:`
4. Run `mkdocs serve` locally to preview your changes
5. Open a pull request

All content lives in `docs/`. The site structure is defined in `mkdocs.yml`.
