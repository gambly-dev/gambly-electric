# gambly-electric (dev)

This directory contains Kubernetes manifests for deploying Electric in `gambly-dev`.

## Provisioned AWS resources

- EFS filesystem: `fs-0b37043cf4d3bd4bc`
- EFS access point: `fsap-074e9b709e11f0aa0`
- EFS security group: `sg-062bf9e42023addd8`

## Required environment variables

Export these before running the deploy script:

```bash
export GAMBLY_ELECTRIC_DATABASE_URL='postgresql://postgres:...@gambly-core-dev.c1bavukht5fd.us-east-2.rds.amazonaws.com:5432/gambly_core?sslmode=require'
export GAMBLY_ELECTRIC_SECRET='replace-with-strong-random-secret'
```

## Deploy

```bash
./scripts/deploy-gambly-electric-dev.sh
```

## Smoke test

```bash
export DATABASE_URL="$GAMBLY_ELECTRIC_DATABASE_URL"
export ELECTRIC_SECRET="$GAMBLY_ELECTRIC_SECRET"

# Local port-forward test
kubectl -n gambly-dev port-forward svc/gambly-electric 3000:80
ELECTRIC_BASE_URL='http://localhost:3000' ./scripts/test-electric-shape-sync.sh
```

## Ingress host

Ingress is configured for `dev-electric.gambly.com` in `k8s/dev/ingress.yaml`.
Create the corresponding Route53 record before testing this host.

To create the record (A alias only, no edits to existing records):

```bash
./scripts/create-dev-electric-route53.sh
```
