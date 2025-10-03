# Auto Healing

One of Kubernetes' most powerful properties is self-healing: the cluster continuously reconciles what *is* running against what *should* be running. If a pod dies, it comes back. If a node reboots, its workloads restart elsewhere.

This chapter demonstrates how self-healing works and how to configure your apps to work with it correctly.

---

## How Kubernetes restarts pods

A `Deployment` doesn't run pods directly - it creates a `ReplicaSet` that maintains the desired number of pod replicas. The `ReplicaSet` controller runs in the background and watches:

- If a pod is deleted → create a new one
- If a pod crashes and exits → restart it
- If a node goes down → reschedule the pods on another node

The controller loop runs every few seconds. Recovery from a crashed pod is typically complete within 5-15 seconds.

---

## Demo 1: Pod self-healing

Deploy the whoami app with 2 replicas:

```bash
kubectl apply -f whoami.yaml     # from the Hello World chapter
kubectl get pods
```

```
NAME                      READY   STATUS    RESTARTS   AGE
whoami-7d6b9c8f9b-abcd1   1/1     Running   0          30s
whoami-7d6b9c8f9b-efgh2   1/1     Running   0          30s
```

In a second terminal, watch the pods continuously:

```bash
kubectl get pods -w
```

In the first terminal, delete one pod:

```bash
kubectl delete pod whoami-7d6b9c8f9b-abcd1
```

In the watch terminal you'll see:

```
whoami-7d6b9c8f9b-abcd1   1/1   Running     0   45s
whoami-7d6b9c8f9b-abcd1   1/1   Terminating 0   46s
whoami-7d6b9c8f9b-wxyz3   0/1   Pending     0   0s
whoami-7d6b9c8f9b-wxyz3   0/1   ContainerCreating 0   1s
whoami-7d6b9c8f9b-wxyz3   1/1   Running     0   3s
```

The ReplicaSet detected one missing replica and created a replacement within seconds. The Deployment always maintains 2 running pods - even when you manually delete one.

---

## Demo 2: Crash loop recovery

Simulate a crashing container by running a pod that exits immediately:

```bash
kubectl run crasher \
  --image=busybox \
  --restart=Always \
  -- /bin/sh -c "echo 'starting'; sleep 2; echo 'crashing'; exit 1"
```

Watch it:

```bash
kubectl get pod crasher -w
```

```
crasher   0/1   ContainerCreating   0          2s
crasher   1/1   Running             0          3s
crasher   0/1   Error               0          5s
crasher   0/1   CrashLoopBackOff    1          8s
crasher   1/1   Running             1          18s
crasher   0/1   Error               1          20s
```

Kubernetes restarts the container with exponential backoff - 10s, 20s, 40s, etc. - to avoid thrashing. After too many restarts, the pod enters `CrashLoopBackOff`.

Clean up:

```bash
kubectl delete pod crasher
```

---

## Liveness and readiness probes

Kubernetes has no way to know if your app is *working* - only that the process is *running*. A web server could be running but returning 500 errors for every request. Probes close this gap.

### Liveness probe

If the liveness probe fails, Kubernetes kills the container and restarts it.

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10    # wait before first check (time to start up)
  periodSeconds: 10          # check every 10 seconds
  failureThreshold: 3        # restart after 3 consecutive failures
```

### Readiness probe

If the readiness probe fails, Kubernetes stops routing traffic to the pod (but doesn't restart it). Use this to hold traffic until the app finishes starting up or loading data.

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 2
```

### Example: deployment with both probes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resilient-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resilient-app
  template:
    metadata:
      labels:
        app: resilient-app
    spec:
      containers:
      - name: app
        image: traefik/whoami
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 2
```

Apply and test:

```bash
kubectl apply -f resilient-app.yaml
kubectl describe pod -l app=resilient-app | grep -A 10 "Liveness\|Readiness"
```

---

## Resource requests and limits

Resource **requests** tell the scheduler how much CPU and memory a pod needs. Resource **limits** cap what it can use. Setting these correctly is important for cluster stability:

- Without requests, the scheduler can't make good placement decisions
- Without limits, a single pod can starve other pods of resources

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"       # 100 millicores = 0.1 CPU core
  limits:
    memory: "128Mi"
    cpu: "200m"
```

If a container exceeds its memory limit, it's OOM-killed and restarted. CPU is throttled (not killed) when the limit is exceeded.

View current resource usage:

```bash
kubectl top pods
kubectl top nodes
```

---

## Pod Disruption Budgets

For critical applications, a `PodDisruptionBudget` (PDB) prevents Kubernetes from taking down too many replicas at once during voluntary disruptions (node drains, upgrades):

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: whoami-pdb
  namespace: default
spec:
  minAvailable: 1     # always keep at least 1 pod running
  selector:
    matchLabels:
      app: whoami
```

Without a PDB, draining a node could stop all pods of a single-replica deployment simultaneously.

---

## Summary

| Mechanism | What it does |
|---|---|
| ReplicaSet | Ensures the right number of pod replicas are always running |
| Liveness probe | Restarts unhealthy pods |
| Readiness probe | Keeps traffic away from not-yet-ready pods |
| Resource limits | Prevents resource exhaustion from crashing the node |
| PodDisruptionBudget | Maintains availability during maintenance |

These five mechanisms together give you a highly resilient application with no manual intervention.

---

[Set up PostgreSQL :material-arrow-right:](../databases/postgres.md){ .md-button .md-button--primary }
