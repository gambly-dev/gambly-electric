# gambly-electric (prod)

This directory contains Kubernetes manifests for deploying Electric in `gambly-prod`.

Before deploying from `main`, replace these placeholders in `k8s/prod/pv.yaml`:

- `fs-REPLACE_ME`
- `fsap-REPLACE_ME`

They should point to your production EFS filesystem and access point.
