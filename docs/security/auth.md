# Authentication

Internal dashboards - Traefik, Grafana, Longhorn UI - should not be accessible to anyone without credentials. This chapter shows how to add HTTP Basic Authentication using a Traefik middleware.

Note that Basic Authentication is a shared secret. It verifies that someone knows the password, but not *who* is logged in. For team or production environments, consider an identity-aware solution instead. See [Going further](#going-further-oauth2-oidc).

---

## Why protect dashboards?

Dashboards expose sensitive information: routing configuration, metrics, storage state, pod logs. Even if your cluster is on a VPS with a firewall, don't rely on obscurity. If a port is open, put auth in front of it.

---

## Traefik middlewares

Traefik **Middlewares** are reusable filters that you attach to routes. They transform requests before passing them to your backend. Auth, rate limiting, redirects, and headers are all middleware.

You define a middleware once and reference it from any IngressRoute or Ingress.

---

## Create a BasicAuth middleware

**Step 1 - Generate a hashed password**

Install `htpasswd` (part of `apache2-utils`):

```bash
sudo apt install -y apache2-utils
```

Generate a hashed entry for user `admin`:

```bash
htpasswd -nb admin YOUR_PASSWORD
```

Output (the exact hash will differ):

```
admin:$apr1$X7jQqXxx$xxxxxxxxxxxxxxxxxxxxxxxx/
```

Copy the full output string - you need it in the next step.

**Step 2 - Base64-encode the htpasswd string**

Kubernetes Secrets store values as base64:

```bash
echo -n 'admin:$apr1$X7jQqXxx$xxxxxxxxxxxxxxxxxxxxxxxx/' | base64
```

Copy the base64 output.

**Step 3 - Create the Secret and Middleware**

```yaml
# basic-auth.yaml
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth-secret
  namespace: kube-system      # use the same namespace as the route
type: Opaque
data:
  users: BASE64_OUTPUT_HERE   # paste your base64 string
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: basic-auth
  namespace: kube-system
spec:
  basicAuth:
    secret: basic-auth-secret
```

Apply:

```bash
kubectl apply -f basic-auth.yaml
```

---

## Attach the middleware to a route

Reference the middleware in an `IngressRoute` using the `namespace-name@kubernetescrd` format:

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
  - match: Host(`traefik.YOUR_DOMAIN.com`)
    kind: Rule
    services:
    - name: api@internal
      kind: TraefikService
    middlewares:
    - name: basic-auth          # middleware name in the same namespace
  tls:
    certResolver: letsencrypt
```

Apply:

```bash
kubectl apply -f traefik-dashboard-ingress.yaml
```

Now `https://traefik.YOUR_DOMAIN.com` will prompt for a username and password.

---

## Using middleware with standard Ingress

If you're using the standard `Ingress` resource instead of `IngressRoute`, reference the middleware via an annotation:

```yaml
annotations:
  traefik.ingress.kubernetes.io/router.middlewares: kube-system-basic-auth@kubernetescrd
```

The format is `NAMESPACE-MIDDLEWARE_NAME@kubernetescrd`.

---

## Managing multiple users

The htpasswd file supports multiple users - one per line:

```bash
# Create a new file with admin user
htpasswd -c auth.htpasswd admin

# Add a second user (no -c flag - that would overwrite)
htpasswd auth.htpasswd developer

# View the file
cat auth.htpasswd

# Create the Secret from the file
kubectl create secret generic basic-auth-secret \
  --from-file=users=auth.htpasswd \
  --namespace=kube-system \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## Namespaced middlewares

Traefik Middlewares are namespace-scoped. If you have apps in different namespaces, you have two options:

**Option A** - Create the same middleware in each namespace (simple, duplicated).

**Option B** - Put the middleware in a shared namespace (e.g. `kube-system`) and reference it from other namespaces using the `NAMESPACE-NAME@kubernetescrd` format.

For most single-developer setups, Option A is simpler.

---

## Going further: OAuth2 / OIDC

Basic Auth is sufficient for personal clusters. For team use, consider full OAuth2/OIDC with providers like:

- **[Authelia](https://www.authelia.com/)** - Self-hosted, supports 2FA and LDAP
- **[Authentik](https://goauthentik.io/)** - Full-featured identity provider, Kubernetes-native
- **[Dex](https://dexidp.io/)** - CNCF project, integrates with GitHub/Google/etc.

These forward authentication requests to an identity provider, so you get SSO across all your cluster dashboards.

---

[Set up Persistent Storage :material-arrow-right:](../storage/longhorn.md){ .md-button .md-button--primary }
