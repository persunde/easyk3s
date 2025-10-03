# HTTPS with Let's Encrypt

Serve your apps over HTTPS with automatically renewing TLS certificates from Let's Encrypt. We use **cert-manager** - the standard Kubernetes add-on for certificate management.

---

## How it works

```
Your domain DNS (A record → server IP)
     │
     ▼
cert-manager                 ← watches Certificate resources
     │ requests cert from
     ▼
Let's Encrypt ACME           ← validates domain ownership
     │ via HTTP-01 challenge
     ▼
Traefik serves HTTP on :80   ← Let's Encrypt verifies /.well-known/acme-challenge/
     │
     ▼
cert-manager stores cert as a Kubernetes Secret
     │
     ▼
Traefik uses the Secret for TLS on :443
```

cert-manager watches for `Certificate` objects (or `Ingress` annotations) and automatically requests, renews, and rotates certificates.

---

## Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
```

Wait for all cert-manager pods to be running:

```bash
kubectl get pods -n cert-manager --watch
```

All three pods (`cert-manager`, `cert-manager-cainjector`, `cert-manager-webhook`) should reach `Running` status within about a minute.

---

## Create a ClusterIssuer

A `ClusterIssuer` tells cert-manager how to obtain certificates - in this case, via the Let's Encrypt ACME protocol using HTTP-01 validation.

!!! tip "Test with staging first"
    Let's Encrypt has strict rate limits on the production API. Always test with the **staging** issuer first. Staging certificates are not trusted by browsers but let you verify the full workflow without burning your rate limit quota.

**Staging issuer** (use this first):

```yaml
# cluster-issuer-staging.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your@email.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          ingressClassName: traefik
```

**Production issuer** (use once staging works):

```yaml
# cluster-issuer-prod.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your@email.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          ingressClassName: traefik
```

Replace `your@email.com` with your real email - Let's Encrypt sends expiry warnings there.

Apply both:

```bash
kubectl apply -f cluster-issuer-staging.yaml
kubectl apply -f cluster-issuer-prod.yaml
```

Verify they're ready:

```bash
kubectl get clusterissuer
```

```
NAME                   READY   AGE
letsencrypt-prod       True    30s
letsencrypt-staging    True    30s
```

---

## Update whoami to use HTTPS

Update your `whoami.yaml` Ingress to request a certificate:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging   # change to letsencrypt-prod once verified
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  tls:
  - hosts:
    - whoami.YOUR_DOMAIN.com
    secretName: whoami-tls
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

Apply it:

```bash
kubectl apply -f whoami.yaml
```

---

## Verify the certificate

Watch cert-manager request and issue the certificate:

```bash
kubectl describe certificate whoami-tls -n default
```

The `Events` section will show the lifecycle:
```
  Normal  Issuing    Generating a new private key
  Normal  Issuing    Waiting for CertificateRequest to complete
  Normal  Issued     Certificate issued successfully
```

Check the certificate status:

```bash
kubectl get certificate -n default
```

```
NAME        READY   SECRET      AGE
whoami-tls  True    whoami-tls  2m
```

`READY: True` means the certificate was issued and is stored in the `whoami-tls` Secret.

Test HTTPS (staging certs show a browser warning - that's expected):

```bash
curl -k https://whoami.YOUR_DOMAIN.com
```

---

## Switch to production

Once staging works, update the annotation in your Ingress:

```yaml
cert-manager.io/cluster-issuer: letsencrypt-prod
```

Delete the old staging secret so cert-manager requests a fresh production certificate:

```bash
kubectl delete secret whoami-tls -n default
kubectl apply -f whoami.yaml
```

A new production certificate will be requested automatically. After ~30 seconds, `https://whoami.YOUR_DOMAIN.com` should show a valid, browser-trusted certificate.

---

## Reuse for every app

The pattern is always the same. For any new app, add these two things to its Ingress:

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
  traefik.ingress.kubernetes.io/router.tls: "true"

spec:
  tls:
  - hosts:
    - YOUR_APP.YOUR_DOMAIN.com
    secretName: YOUR_APP-tls
```

cert-manager handles everything else - requesting, storing, and auto-renewing the certificate.

---

## Enable HTTP → HTTPS redirect

Now that HTTPS is working, enable the HTTP-to-HTTPS redirect in Traefik. Update `traefik-config.yaml`:

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
    ports:
      web:
        redirectTo:
          port: websecure
```

Apply and wait for Traefik to restart:

```bash
kubectl rollout status deployment/traefik -n kube-system
```

HTTP requests to port 80 now redirect to port 443 automatically.

---

## Move the Traefik dashboard to a domain

Earlier you accessed the dashboard at `http://YOUR_SERVER_IP/dashboard/` with no hostname. Now that HTTPS is working, replace that IngressRoute with one that uses a proper domain and TLS.

Delete the old one first:

```bash
kubectl delete -f traefik-dashboard-ingress.yaml
```

Apply the new one:

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
  - websecure
  routes:
  - match: Host(`traefik.YOUR_DOMAIN.com`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))
    kind: Rule
    services:
    - name: api@internal
      kind: TraefikService
  tls:
    certResolver: letsencrypt
```

Replace `traefik.YOUR_DOMAIN.com` with your subdomain and make sure you have an A record pointing at your server.

Visit the dashboard:

```
https://traefik.YOUR_DOMAIN.com/dashboard/
```

!!! warning "Add authentication before sharing this URL"
    The dashboard is now on HTTPS but still has no login. Anyone with the URL can see your routing config. Add a BasicAuth middleware before exposing this to the internet — see the [Authentication](../security/auth.md) chapter.

---

[Set up Authentication :material-arrow-right:](../security/auth.md){ .md-button .md-button--primary }
