# gambly-electric (prod)

This directory contains Kubernetes manifests for deploying Electric in `gambly-prod`.

## Provisioned AWS resources

- EFS filesystem: `fs-0ade713452d6b7f7b`
- EFS access point: `fsap-0407f2e3b4e5698e6`
- EFS security group: `sg-00bcfb0bbca83c72d`

## Environment file

Production env vars are read from:

- `s3://gambly-env/prod/gambly-electric.env`

Expected keys:

- `DATABASE_URL`
- `ELECTRIC_SECRET`

## Deploy

From a machine with EKS access:

```bash
./scripts/deploy-gambly-electric.sh prod
```

Or via GitHub Actions:

- Push to `main`, or
- Run the `Deploy Electric` workflow with `environment=prod`

## Smoke test

```bash
# Local port-forward test
kubectl -n gambly-prod port-forward svc/gambly-electric 3000:80
ELECTRIC_BASE_URL='http://localhost:3000' ./scripts/test-electric-shape-sync.sh
```

## Shape DB rollout and cleanup

Production uses EFS for `ELECTRIC_STORAGE_DIR`, but Electric's ShapeDb should run
on local ephemeral storage to avoid EFS read contention. The prod deployment
mounts `/var/lib/electric/shape-db` as `emptyDir` via
`ELECTRIC_SHAPE_DB_STORAGE_DIR`, while durable log/state data stays on
`/var/lib/electric/persistent`.

### Rollout checks

Deploy the manifest, then verify:

```bash
kubectl -n gambly-prod rollout status deploy/gambly-electric --timeout=10m
kubectl -n gambly-prod top pod -l app=gambly-electric
kubectl -n gambly-prod logs deploy/gambly-electric --since=10m | \
  rg "Consumers ready|Restored filters|NimblePool.checkout|Stack not ready"
```

Expected result:

- `Consumers ready` appears after startup
- no repeating `NimblePool.checkout(... ShapeDb.Connection, :read)` errors
- no repeated readiness probe failures

### Stale ShapeDb cleanup/reset

Once the new pod is healthy, the old ShapeDb files on EFS are no longer used.
They can be removed after a controlled reset.

1. Scale Electric down to avoid touching stale on-EFS ShapeDb files during cleanup.
2. Inspect the EFS-backed meta directory and confirm only stale ShapeDb files are targeted.
3. Remove the old ShapeDb directories, including any pre-recovery snapshot.
4. Scale Electric back up and verify the pod rebuilds ShapeDb from the durable logs.

Suggested command sequence:

```bash
kubectl -n gambly-prod scale deploy/gambly-electric --replicas=0
kubectl -n gambly-prod wait --for=delete pod -l app=gambly-electric --timeout=5m

kubectl -n gambly-prod run electric-cleanup \
  --rm -i --tty \
  --restart=Never \
  --image=alpine:3.20 \
  --overrides='
{
  "spec": {
    "containers": [
      {
        "name": "electric-cleanup",
        "image": "alpine:3.20",
        "command": ["sh", "-lc", "ls -lah /mnt/meta && rm -rf /mnt/meta/shape-db /mnt/meta/shape-db.pre_recovery_*"],
        "volumeMounts": [
          {
            "name": "electric-storage",
            "mountPath": "/mnt"
          }
        ]
      }
    ],
    "volumes": [
      {
        "name": "electric-storage",
        "persistentVolumeClaim": {
          "claimName": "gambly-electric"
        }
      }
    ]
  }
}'

kubectl -n gambly-prod scale deploy/gambly-electric --replicas=1
kubectl -n gambly-prod rollout status deploy/gambly-electric --timeout=10m
```

This reset invalidates cached shape handles and forces fresh snapshots for
clients, which is expected.

## Ingress host

Ingress is configured for `electric.gambly.com` in `k8s/prod/ingress.yaml`.
Create the corresponding Route53 record before testing this host.

To create the record (A alias only, no edits to existing records):

```bash
./scripts/create-prod-electric-route53.sh
```
