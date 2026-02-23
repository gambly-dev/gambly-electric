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

## Ingress host

Ingress is configured for `electric.gambly.com` in `k8s/prod/ingress.yaml`.
Create the corresponding Route53 record before testing this host.

To create the record (A alias only, no edits to existing records):

```bash
./scripts/create-prod-electric-route53.sh
```
