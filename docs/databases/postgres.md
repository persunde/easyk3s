# PostgreSQL on Kubernetes

**Don't try this at work, DO try this at home!** Running Postgres on Kubernetes without a solid grasp of both can end very badly for your production data. This guide is for learning, don't let it be the reason for your next oncall incident.

Running stateful databases on Kubernetes requires careful handling of persistent storage, failover, backups, and connection management. This is a more advanced topic than the rest of this guide. This guide will only cover the very surface level aspects of runing Postgres on Kubernetes. Go to [**CloudNativePG**](https://cloudnative-pg.io/) and read the documentation thoroughly.

---

## The recommended approach: CloudNativePG

[**CloudNativePG**](https://cloudnative-pg.io/) is a CNCF-graduated Kubernetes operator for PostgreSQL. It handles:

- Automated primary/replica setup
- Automatic failover and promotion
- Continuous WAL archiving to S3/object storage
- Point-in-time recovery (PITR)
- Connection pooling with PgBouncer
- Scheduled backups
- Rolling updates with zero downtime

It integrates natively with Kubernetes - clusters are defined as CRDs, everything is managed via `kubectl`.

---

## Quick install reference

Install the CloudNativePG operator:

```bash
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/releases/cnpg-1.23.0.yaml
```

Verify:

```bash
kubectl get pods -n cnpg-system
```

A minimal PostgreSQL cluster definition:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: my-postgres
  namespace: default
spec:
  instances: 3                # 1 primary + 2 replicas
  storage:
    storageClass: longhorn
    size: 10Gi
  bootstrap:
    initdb:
      database: mydb
      owner: myuser           # Change to your wanted username
      secret:
        name: myuser-secret   # Kubernetes Secret with username/password
```

---

## Go deeper

The CloudNativePG documentation is comprehensive and production-focused. This is where you should continue:

<div class="grid cards" markdown>

-   :material-book-open-variant: **[CloudNativePG Documentation](https://cloudnative-pg.io/documentation/current/)**

    Complete guide covering installation, cluster configuration, backups, monitoring, and production hardening.

-   :material-github: **[CloudNativePG GitHub](https://github.com/cloudnative-pg/cloudnative-pg)**

    Source code, issue tracker, and community discussions.

</div>

---

## Things to understand before running a database in production

!!! warning "Databases need more care than stateless apps"
    Before running PostgreSQL in your K3S cluster for anything important, make sure you understand:

    - **Backup and restore** - Configure WAL archiving to object storage (S3, Backblaze B2). Test your restore procedure before you need it.
    - **Storage reliability** - Use Longhorn with at least 3 replicas on a multi-node cluster, or a network-attached volume.
    - **Connection limits** - Use PgBouncer for connection pooling. PostgreSQL has a hard limit on concurrent connections.
    - **Monitoring** - CloudNativePG integrates with Prometheus out of the box. Import the official Grafana dashboard.
    - **Upgrades** - Major PostgreSQL version upgrades require a deliberate process (pg_upgrade or dump/restore).

