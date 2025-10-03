# Logging with Loki

Metrics tell you what your cluster is doing - logs tell you *why*. This chapter adds **Loki** (log aggregation) and **Promtail** (log shipper) to your cluster and integrates them into the Grafana instance you already have.

---

## How it works

```
Every pod writes logs to stdout/stderr
         │
         ▼
Promtail (DaemonSet)    ← runs on every node, tails container log files
         │ ships logs to
         ▼
Loki                    ← stores and indexes logs
         │
         ▼
Grafana → Explore       ← query and visualise logs with LogQL
```

Loki is designed to be **cheap and simple**. Unlike Elasticsearch, it doesn't index the content of log lines - it indexes only labels (namespace, pod name, container name). This makes it inexpensive to run and fast for label-based filtering.

---

## Install Loki Stack

We install Loki and Promtail but skip Grafana (you already have it from the metrics chapter):

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set prometheus.enabled=false
```

Watch the pods:

```bash
kubectl get pods -n monitoring | grep loki
```

You should see one `loki-0` pod (StatefulSet) and a `loki-promtail-xxxxx` pod on each node.

---

## Add Loki as a Grafana datasource

There are two ways to do this.

=== "Via the Grafana UI (quick)"
    1. Go to `https://grafana.YOUR_DOMAIN.com`
    2. Open **Connections** → **Data sources** → **Add data source**
    3. Select **Loki**
    4. Set URL to: `http://loki:3100`
    5. Click **Save & test** - you should see "Data source connected"

=== "Via a ConfigMap (repeatable)"
    Create a ConfigMap in the monitoring namespace - Grafana sidecar picks it up automatically:

    ```yaml
    # loki-datasource.yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: loki-datasource
      namespace: monitoring
      labels:
        grafana_datasource: "1"        # the sidecar watches for this label
    data:
      loki-datasource.yaml: |-
        apiVersion: 1
        datasources:
        - name: Loki
          type: loki
          url: http://loki:3100
          access: proxy
          isDefault: false
    ```

    ```bash
    kubectl apply -f loki-datasource.yaml
    ```

---

## Browse logs in Grafana

Go to **Explore** (compass icon) and select **Loki** as the datasource.

Use the label browser or type a **LogQL** query directly. LogQL is a simple query language:

```logql
# All logs from the default namespace
{namespace="default"}

# Logs from a specific app
{app="whoami"}

# Filter for errors
{namespace="default"} |= "error"

# Logs from Traefik
{namespace="kube-system", app="traefik"}

# Parse and filter JSON logs
{app="my-app"} | json | level="error"

# Count error lines per minute
sum(rate({namespace="default"} |= "error" [1m])) by (pod)
```

---

## Create a log dashboard

1. In Grafana, create a new Dashboard
2. Add a **Logs panel**
3. Set the query to `{namespace="default"}` (or your app's namespace)
4. Add a **Time series panel** to show log volume over time: `sum(rate({namespace="default"}[1m])) by (app)`
5. Save the dashboard

---

## Persist Loki storage on Longhorn

By default, Loki uses ephemeral storage and loses data on restart. For persistent storage:

```bash
helm upgrade loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set prometheus.enabled=false \
  --set loki.persistence.enabled=true \
  --set loki.persistence.storageClassName=longhorn \
  --set loki.persistence.size=10Gi
```

---

## Log retention

Loki's default retention is unlimited - logs accumulate forever. Set a retention period to keep disk usage in check. Add to your Helm upgrade:

```bash
--set loki.config.chunk_store_config.max_look_back_period=720h \
--set loki.config.table_manager.retention_deletes_enabled=true \
--set loki.config.table_manager.retention_period=720h
```

720 hours = 30 days. Adjust to your needs.

---

## Going further

For high-traffic clusters, consider:

- **Loki distributed mode** - scales Loki horizontally (requires object storage like S3)
- **Grafana Alloy** - the next-generation log/metric collector replacing Promtail
- **Log-based alerts** - Grafana can alert on LogQL queries the same way it alerts on Prometheus metrics

---

[Set up Auto Healing :material-arrow-right:](../reliability/auto-healing.md){ .md-button .md-button--primary }
