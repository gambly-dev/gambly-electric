#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="gambly-dev"
DB_URL="${GAMBLY_ELECTRIC_DATABASE_URL:-}"
ELECTRIC_SECRET="${GAMBLY_ELECTRIC_SECRET:-}"

if [[ -z "$DB_URL" ]]; then
  echo "Missing GAMBLY_ELECTRIC_DATABASE_URL env var" >&2
  exit 1
fi

if [[ -z "$ELECTRIC_SECRET" ]]; then
  echo "Missing GAMBLY_ELECTRIC_SECRET env var" >&2
  exit 1
fi

kubectl apply -f k8s/dev/csidriver-efs.yaml
kubectl apply -f k8s/dev/pv.yaml
kubectl apply -f k8s/dev/pvc.yaml

kubectl create secret generic gambly-electric-env \
  --namespace "$NAMESPACE" \
  --from-literal=DATABASE_URL="$DB_URL" \
  --from-literal=ELECTRIC_SECRET="$ELECTRIC_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f k8s/dev/deployment.yaml
kubectl apply -f k8s/dev/service.yaml
kubectl apply -f k8s/dev/ingress.yaml

kubectl rollout status deployment/gambly-electric -n "$NAMESPACE" --timeout=5m
kubectl get pods -n "$NAMESPACE" -l app=gambly-electric
kubectl get svc gambly-electric -n "$NAMESPACE"
kubectl get ingress gambly-ingress-electric -n "$NAMESPACE"
