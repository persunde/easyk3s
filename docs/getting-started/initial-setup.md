# Initial Setup

K3S is running on your server. Now configure kubectl on your local machine to manage the cluster remotely, and take a tour of what's already running.

---

## Configure kubectl

K3S writes a kubeconfig file to `/etc/rancher/k3s/k3s.yaml` on the server. Copy it to your local machine:

=== "From your local machine (recommended)"
    ```bash
    # Replace YOUR_SERVER_IP with your server's public IP or domain
    scp deploy@YOUR_SERVER_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/config

    # Fix the server address (k3s.yaml uses 127.0.0.1 - change it to your server IP)
    sed -i 's/127.0.0.1/YOUR_SERVER_IP/g' ~/.kube/config
    ```

=== "On the server itself"
    ```bash
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $USER:$USER ~/.kube/config
    ```

Test the connection:

```bash
kubectl get nodes
```

You should see your server node with status `Ready`.

!!! warning "Keep your kubeconfig private"
    The kubeconfig file contains credentials that give full admin access to your cluster. Don't commit it to git or share it publicly. Restrict permissions:
    ```bash
    chmod 600 ~/.kube/config
    ```

---

## Tour of the running system

Check what's already running in the `kube-system` namespace:

```bash
kubectl get pods -n kube-system
```

You'll see pods like these:

```
NAME                                      READY   STATUS      RESTARTS
coredns-6799fbcd5-xxxxx                   1/1     Running     0
helm-install-traefik-xxxxx                0/1     Completed   1
helm-install-traefik-crd-xxxxx            0/1     Completed   0
local-path-provisioner-xxxxx              1/1     Running     0
metrics-server-xxxxx                      1/1     Running     0
svclb-traefik-xxxxx                       2/2     Running     0
traefik-xxxxx                             1/1     Running     0
```

What each one does:

| Pod | Purpose |
|---|---|
| `coredns` | DNS resolution inside the cluster |
| `traefik` | Ingress controller - the entry point for HTTP/HTTPS traffic |
| `svclb-traefik` | K3S's built-in ServiceLB - binds Traefik to host ports 80 and 443 |
| `local-path-provisioner` | Creates PersistentVolumes on the host filesystem |
| `metrics-server` | Aggregates CPU/memory metrics for `kubectl top` |
| `helm-install-*` | One-time Jobs that installed Traefik via Helm on cluster startup |

---

## Essential kubectl commands

You'll use these throughout the guide. Here's a quick reference:

```bash
# List resources
kubectl get pods                        # pods in default namespace
kubectl get pods -n kube-system         # pods in kube-system namespace
kubectl get pods --all-namespaces       # all namespaces
kubectl get nodes                       # cluster nodes
kubectl get services                    # services
kubectl get ingress                     # ingress rules
kubectl get pvc                         # persistent volume claims

# Inspect a resource
kubectl describe pod <pod-name>
kubectl describe node <node-name>

# View logs
kubectl logs <pod-name>
kubectl logs <pod-name> -f              # follow (live tail)
kubectl logs <pod-name> -c <container>  # specific container

# Execute a command inside a pod
kubectl exec -it <pod-name> -- /bin/sh

# Apply / delete manifests
kubectl apply -f manifest.yaml
kubectl delete -f manifest.yaml

# Real-time resource usage
kubectl top nodes
kubectl top pods
```

---

## Namespaces

Kubernetes uses namespaces to isolate resources. Think of them as folders:

```bash
kubectl get namespaces
```

```
NAME              STATUS
default           Active   # your apps go here by default
kube-system       Active   # Kubernetes and K3S system components
kube-public       Active   # publicly readable (rarely used)
kube-node-lease   Active   # node heartbeats
```

When you apply a manifest without specifying a namespace, it goes into `default`. You can add a `-n <namespace>` flag to any kubectl command to target a specific namespace, or set a `namespace:` field in your manifest's `metadata`.

