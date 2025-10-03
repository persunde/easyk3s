# Persistent Storage with Longhorn

By default, K3S uses `local-path-provisioner` for persistent volumes - data lives in a directory on the node's filesystem. That's fine for development, but if the node is replaced or rebooted unexpectedly, data can be lost and volumes aren't accessible from other nodes.

[Longhorn](https://longhorn.io) is a distributed block storage system built for Kubernetes. It replicates data across nodes and survives node failures.

---

## Why Longhorn?

| | local-path | Longhorn |
|---|---|---|
| Data replication | ✗ | ✓ (configurable replicas) |
| Survives node failure | ✗ | ✓ |
| Web UI | ✗ | ✓ |
| Snapshots & backups | ✗ | ✓ |
| ReadWriteMany (NFS-like) | ✗ | ✓ |
| Complexity | Low | Medium |

For a single-node cluster, Longhorn's main benefit is snapshots and backups rather than replication. On multi-node clusters, it provides true high availability for stateful workloads.

---

## Prerequisites

Longhorn requires `open-iscsi` on every node (it uses iSCSI to mount volumes):

```bash
sudo apt install -y open-iscsi nfs-common
sudo systemctl enable --now iscsid
```

Verify iSCSI is running:

```bash
sudo systemctl status iscsid
```

---

## Install Longhorn

Add the Helm repo and install:

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update

kubectl create namespace longhorn-system

helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --set defaultSettings.defaultReplicaCount=1
```

!!! tip "Replica count"
    On a single-node cluster, set `defaultReplicaCount=1` - you only have one node to store data on anyway. On a 3-node cluster, use `defaultReplicaCount=3` for full redundancy.

Watch the pods come up (takes 2-3 minutes):

```bash
kubectl get pods -n longhorn-system --watch
```

All pods should reach `Running` status.

---

## Expose the Longhorn UI

```yaml
# longhorn-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ui
  namespace: longhorn-system
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: kube-system-basic-auth@kubernetescrd
spec:
  tls:
  - hosts:
    - longhorn.YOUR_DOMAIN.com
    secretName: longhorn-tls
  rules:
  - host: longhorn.YOUR_DOMAIN.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
```

Apply:

```bash
kubectl apply -f longhorn-ingress.yaml
```

Visit `https://longhorn.YOUR_DOMAIN.com` - you'll see the Longhorn dashboard showing nodes, volumes, and storage capacity.

---

## Set Longhorn as the default StorageClass

Make Longhorn the default so PVCs use it automatically:

```bash
# Set Longhorn as default
kubectl patch storageclass longhorn \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Remove the default flag from local-path
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

Verify:

```bash
kubectl get storageclass
```

```
NAME                   PROVISIONER             DEFAULT
local-path             rancher.io/local-path
longhorn (default)     driver.longhorn.io      ✓
```

---

## Create a PersistentVolumeClaim

PVCs request storage from the cluster. Once bound, you mount the PVC into a pod.

```yaml
# my-data-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
```

Apply:

```bash
kubectl apply -f my-data-pvc.yaml
kubectl get pvc
```

```
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
my-data   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   5Gi        RWO            longhorn
```

`STATUS: Bound` means Longhorn created the volume and it's ready to use.

---

## Mount the PVC in a pod

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-storage
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-with-storage
  template:
    metadata:
      labels:
        app: app-with-storage
    spec:
      containers:
      - name: app
        image: nginx
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: my-data
```

The container sees the volume at `/data`. Data written there persists across pod restarts and rescheduling.

---

## Snapshots and backups

From the Longhorn UI you can:

- **Take a volume snapshot** - point-in-time copy, stored on the same node
- **Create a backup** - copies snapshot data to an S3-compatible remote store

To configure remote backups, go to the Longhorn UI → Settings → Backup Target and provide an S3 URL and credentials.

!!! tip "Backup for single-node clusters"
    Even on a single node, configure a remote backup target (e.g. AWS S3, MinIO, Cloudflare R2). A hardware failure without remote backups means permanent data loss.

---

[Set up Metrics :material-arrow-right:](../observability/metrics.md){ .md-button .md-button--primary }
