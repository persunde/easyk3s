# Hello World

Deploy a test app and reach it immediately via your server's public IP.

---

## Deployment

Create the Deployment:

```bash
kubectl apply -f whoami-deployment.yaml
```

**whoami-deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
      - name: whoami
        image: traefik/whoami
        ports:
        - containerPort: 80
```

## Service

```bash
kubectl apply -f whoami-service.yaml
```

**whoami-service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: whoami
  namespace: default
spec:
  selector:
    app: whoami
  ports:
  - port: 80
    targetPort: 80
```

## Ingress

Notice there is no `host:` field. This makes the rule match any hostname or IP address, so Traefik will route requests to `/hello` regardless of how the server is addressed.

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
  - http:
      paths:
      - path: /hello
        pathType: Prefix
        backend:
          service:
            name: whoami
            port:
              number: 80
```

---

## Test it

```bash
curl http://YOUR_SERVER_IP/hello
```

Expected response:

```
Hostname: whoami-7d6b9c8f9b-abcd1
IP: 10.42.0.15
RemoteAddr: 10.42.0.1:54321
GET /hello HTTP/1.1
Host: YOUR_SERVER_IP
User-Agent: curl/7.81.0
X-Forwarded-For: 10.42.0.1
X-Forwarded-Host: YOUR_SERVER_IP
X-Forwarded-Proto: http
X-Real-Ip: 10.42.0.1
```

Run it a few more times and the `Hostname` in the response will alternate between your two pods as Traefik load-balances across them.

---

## Note: combined vs separate files

Above we applied the three resources separately. You can also combine them into a single file with `---` as a separator:

```yaml
# whoami.yaml
<Deployment>
---
<Service>
---
<Ingress>
```

Then apply everything at once:

```bash
kubectl apply -f whoami.yaml
kubectl delete -f whoami.yaml   # to tear down
```

---

## Clean up

```bash
kubectl delete -f whoami-ingress.yaml
kubectl delete -f whoami-service.yaml
kubectl delete -f whoami-deployment.yaml
```

---

In the next section you'll expose the app on a real domain name using a hostname-based Ingress rule.

[Expose with Ingress :material-arrow-right:](expose-ingress.md){ .md-button .md-button--primary }
