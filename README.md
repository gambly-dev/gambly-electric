# gambly-electric

Infrastructure and deployment automation for ElectricSQL in Gambly Kubernetes.

## Branches

- `dev` -> deploys to `gambly-dev`
- `main` -> deploys to `gambly-prod`

## What this repo contains

- Kubernetes manifests in `k8s/dev` and `k8s/prod`
- Deploy/test scripts in `scripts/`
- GitHub Actions CI/CD workflows in `.github/workflows/`

`k8s/prod/pv.yaml` is intentionally scaffolded with `REPLACE_ME` placeholders so main-branch deploys do not proceed until production EFS is configured.

## CI/CD expectations

The deploy workflow expects:

- GitHub secrets:
  - `DEPLOYER_AWS_ACCESS_KEY_ID`
  - `DEPLOYER_AWS_SECRET_ACCESS_KEY`
- S3 environment files:
  - `s3://gambly-env/dev/gambly-electric.env`
  - `s3://gambly-env/prod/gambly-electric.env`

Each env file should contain at minimum:

```env
DATABASE_URL=postgresql://...
ELECTRIC_SECRET=...
```

## Manual deploy

```bash
export GAMBLY_ELECTRIC_DATABASE_URL='postgresql://...'
export GAMBLY_ELECTRIC_SECRET='...'

./scripts/deploy-gambly-electric.sh dev
# or
./scripts/deploy-gambly-electric.sh prod
```

## Smoke test

```bash
export DATABASE_URL='postgresql://...'
export ELECTRIC_SECRET='...'
export ELECTRIC_BASE_URL='https://dev-electric.gambly.com'

./scripts/test-electric-shape-sync.sh
```
