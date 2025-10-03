# Traefik Ingress

Traefik is the ingress controller bundled with K3S. It listens on ports 80 and 443 on your server and routes incoming HTTP/HTTPS requests to the right pods based on hostname and path rules.

---

## Verify Traefik is running

```bash
kubectl get pods -n kube-system | grep traefik
```

```
traefik-d7c9c5b7-xxxxx   1/1   Running   0   5m
```

Check what ports it's exposing:

```bash
kubectl get service traefik -n kube-system
```

```
NAME      TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
traefik   LoadBalancer   10.43.x.x      YOUR_SERVER_IP   80:32080/TCP,443:32443/TCP
```

The `EXTERNAL-IP` is your server's public IP and K3S's built-in ServiceLB binds Traefik directly to the host network.

---

## Entrypoints

Traefik has two built-in entrypoints in K3S:

| Entrypoint | Port | Use |
|---|---|---|
| `web` | 80 | HTTP |
| `websecure` | 443 | HTTPS (TLS) |

---

## Enable the Traefik dashboard

K3S manages Traefik as a Helm chart. To customise it, create a `HelmChartConfig` and K3S automatically re-applies Traefik with the new values:

```bash
kubectl apply -f traefik-config.yaml
```

**traefik-config.yaml**
```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    dashboard:
      enabled: true
```

Watch Traefik restart:

```bash
kubectl rollout status deployment/traefik -n kube-system
```

---

## Access the dashboard via server IP

Expose the dashboard with an IngressRoute. There is no `Host()` matcher here just a path rule so it is reachable at your server's IP without a domain name.

```bash
kubectl apply -f traefik-dashboard-ingress.yaml
```

**traefik-dashboard-ingress.yaml**
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: kube-system
spec:
  entryPoints:
  - web
  routes:
  - match: PathPrefix(`/dashboard`) || PathPrefix(`/api`)
    kind: Rule
    services:
    - name: api@internal
      kind: TraefikService
```

Open the dashboard in your browser:

```
http://YOUR_SERVER_IP/dashboard/
```

!!! warning "No authentication"
    This exposes the Traefik dashboard to anyone who can reach port 80 on your server. It's fine for initial setup, but once you have HTTPS working you should move it to a domain with authentication. See [HTTPS & Let's Encrypt](https-letsencrypt.md) for the next step.

---

## Ingress vs IngressRoute

You'll encounter two ways to configure routing with Traefik:

| Type | API | When to use |
|---|---|---|
| **Ingress** | `networking.k8s.io/v1` | Standard Kubernetes, works with any ingress controller |
| **IngressRoute** | `traefik.io/v1alpha1` | Traefik-specific CRD that are needed for `api@internal`, middlewares, advanced routing |

For regular app deployments the standard `Ingress` resource is fine. The dashboard uses `IngressRoute` because `api@internal` is a Traefik-native service that can't be referenced from a standard Ingress.

---

## Understanding the Traefik dashboard

The dashboard shows four main sections:

- **Routers** - rules that match incoming requests (hostname, path, headers)
- **Services** - backends that receive traffic (your pods)
- **Middlewares** - transformations applied to requests (auth, redirects, rate limiting)
- **Entrypoints** - the ports Traefik listens on

Every Ingress and IngressRoute you create appears here automatically.

---

Next, set up HTTPS with Let's Encrypt and move the dashboard behind a proper domain.

[HTTPS & Let's Encrypt :material-arrow-right:](https-letsencrypt.md){ .md-button .md-button--primary }
