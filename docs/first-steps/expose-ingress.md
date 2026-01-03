# Expose with Ingress

In the previous step you reached the whoami app at `http://YOUR_SERVER_IP/hello`. That works, but accessing a service using an IP address is not how real services are served. You want a proper hostname like `whoami.example.com` that routes to `/`.

To do that, update the Ingress with a `host:` field. Traefik matches incoming requests by the `Host` header and routes them to the right Service.

---

## Prerequisites

- The whoami Deployment and Service from the [Hello World](first-deployment.md) page must still be running
- A domain name with an A record pointing at your server's IP (see [Prerequisites](../getting-started/prerequisites.md))

---

## Delete the old Ingress

The Ingress from the previous step used a path-based rule with no hostname. Delete it first:

```bash
kubectl delete -f whoami-ingress.yaml
```

## New Ingress with hostname

```bash
kubectl apply -f whoami-ingress.yaml
```

**whoami-ingress.yaml**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami
  namespace: default
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: whoami.YOUR_DOMAIN.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: whoami
            port:
              number: 80
```

Replace `whoami.YOUR_DOMAIN.com` with your actual subdomain.

---

## Test it

```bash
curl http://whoami.YOUR_DOMAIN.com
```

```
Hostname: whoami-7d6b9c8f9b-abcd1
IP: 10.42.0.15
RemoteAddr: 10.42.0.1:54321
GET / HTTP/1.1
Host: whoami.YOUR_DOMAIN.com
User-Agent: curl/7.81.0
X-Forwarded-For: 10.42.0.1
X-Forwarded-Host: whoami.YOUR_DOMAIN.com
X-Forwarded-Proto: http
X-Real-Ip: 10.42.0.1
```

Run it a few times and the `Hostname` will alternate between your two pods as Traefik load-balances across them.

!!! tip "DNS not propagating?"
    If curl returns `curl: (6) Could not resolve host`, the DNS record hasn't propagated yet. Check with:
    ```bash
    dig +short whoami.YOUR_DOMAIN.com
    ```
    It should return your server's IP. If not, wait a few minutes and try again.

---

## How the routing works

With a `host:` field, Traefik only routes requests whose `Host` header matches exactly. Requests to the raw IP or a different hostname won't hit this rule.

Without a `host:` field (like the previous step), Traefik routes any request matching the path regardless of hostname or IP. That's useful for testing but not for production where you have multiple apps behind the same IP.

```
Browser → http://whoami.YOUR_DOMAIN.com
                │
                ▼  Traefik matches Host header
                ▼
        Service: whoami
                │  load-balances across
                ▼
        Pod 1 / Pod 2
```

---

## Routing multiple apps from one server

The real power of Ingress is that you can run many apps on the same server IP, each on its own subdomain:

```yaml
# app-a-ingress.yaml
spec:
  rules:
  - host: app-a.YOUR_DOMAIN.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-a
            port:
              number: 80
---
# app-b-ingress.yaml
spec:
  rules:
  - host: app-b.YOUR_DOMAIN.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-b
            port:
              number: 80
```

Traefik reads all Ingress resources in the cluster and updates its routing table automatically.

---

## Clean up

```bash
kubectl delete -f whoami-ingress.yaml
kubectl delete -f whoami-service.yaml
kubectl delete -f whoami-deployment.yaml
```

---

The app is now accessible on a real domain over HTTP. Next, set up Traefik's dashboard and then add HTTPS.

[Configure Traefik :material-arrow-right:](../networking/traefik.md){ .md-button .md-button--primary }
