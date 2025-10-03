# Metrics with Prometheus and Grafana

Know what your cluster is doing. This chapter installs the **kube-prometheus-stack**. A single Helm chart that bundles Prometheus, Grafana, Alertmanager, and a set of useful pre-built dashboards for Kubernetes.

---

## What you'll get

| Component | Purpose |
|---|---|
| **Prometheus** | Scrapes metrics from your pods, nodes, and Kubernetes control plane |
| **Grafana** | Visualises Prometheus metrics as dashboards and graphs |
| **Alertmanager** | Routes alerts to Slack, email, PagerDuty, etc. |
| **kube-state-metrics** | Exposes Kubernetes object state as metrics (pod counts, resource requests, etc.) |
| **node-exporter** | Exposes host-level metrics (CPU, memory, disk, network) |

The chart comes with over 20 pre-built dashboards for Kubernetes, Nodes, Pods, and Traefik.

---

## Prerequisites

This guide stores Prometheus data on a Longhorn volume. Either complete the [Longhorn setup](../storage/longhorn.md) first, or remove the `storageSpec` block below to use ephemeral storage instead (metrics are lost on restart).

---

## Create values file

Create `prometheus-values.yaml`. This configures Grafana with an Ingress, sets a persistent volume for Prometheus, and sets the admin password:

```yaml
# prometheus-values.yaml
grafana:
  adminPassword: changeme          # change this!
  ingress:
    enabled: true
    ingressClassName: traefik
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      traefik.ingress.kubernetes.io/router.entrypoints: websecure
      traefik.ingress.kubernetes.io/router.tls: "true"
    hosts:
      - grafana.YOUR_DOMAIN.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.YOUR_DOMAIN.com

prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi
```

Replace `grafana.YOUR_DOMAIN.com` and `changeme` with real values.

---

## Install

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f prometheus-values.yaml
```

Watch the pods come up (takes 2-3 minutes):

```bash
kubectl get pods -n monitoring --watch
```

---

## Access Grafana

Visit `https://grafana.YOUR_DOMAIN.com`.

Login: `admin` / the password from `prometheus-values.yaml`.

Navigate to **Dashboards** → Browse. You'll see:

- **Kubernetes / Cluster** - overall cluster health
- **Kubernetes / Nodes** - per-node CPU, memory, disk
- **Kubernetes / Pods** - per-pod resource usage
- **Kubernetes / Workloads** - deployment replica status

---

## Scrape Traefik metrics

K3S's Traefik exposes a metrics endpoint, but kube-prometheus-stack doesn't know about it by default. Create a `ServiceMonitor` to tell Prometheus to scrape it:

First, enable the Traefik metrics endpoint via `HelmChartConfig`:

```yaml
# traefik-config.yaml (update the existing one)
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    dashboard:
      enabled: true
    metrics:
      prometheus:
        entryPoint: metrics
        addEntryPointsLabels: true
        addRoutersLabels: true
        addServicesLabels: true
    ports:
      metrics:
        port: 9100
        expose:
          default: true
        exposedPort: 9100
      web:
        redirectTo:
          port: websecure
```

Then create the ServiceMonitor:

```yaml
# traefik-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: traefik
  namespace: monitoring
  labels:
    release: kube-prometheus-stack    # must match the Helm release label
spec:
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      app.kubernetes.io/name: traefik
  endpoints:
  - port: metrics
    path: /metrics
```

Apply both:

```bash
kubectl apply -f traefik-config.yaml
kubectl apply -f traefik-servicemonitor.yaml
```

After a minute, Prometheus will start collecting Traefik metrics. In Grafana, import dashboard ID **17346** [(Traefik Official Standalone Dashboard)](https://grafana.com/grafana/dashboards/17346-traefik-official-standalone-dashboard/) from grafana.com.

---

## Useful Prometheus queries

From Grafana → Explore → Prometheus, try these PromQL queries:

```promql
# CPU usage per pod
sum(rate(container_cpu_usage_seconds_total{namespace="default"}[5m])) by (pod)

# Memory usage per pod
sum(container_memory_working_set_bytes{namespace="default"}) by (pod)

# HTTP requests per second through Traefik
sum(rate(traefik_router_requests_total[1m])) by (router)

# Nodes memory available
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100
```

---

## Upgrading

To update the stack with new values:

```bash
helm upgrade kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f prometheus-values.yaml
```

---

[Set up Logging :material-arrow-right:](logging.md){ .md-button .md-button--primary }
