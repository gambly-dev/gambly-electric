#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-dev}"
K8S_DIR="k8s/${ENVIRONMENT}"
NAMESPACE="gambly-${ENVIRONMENT}"
DB_URL="${GAMBLY_ELECTRIC_DATABASE_URL:-}"
ELECTRIC_SECRET="${GAMBLY_ELECTRIC_SECRET:-}"

if [[ ! -d "$K8S_DIR" ]]; then
  echo "Missing manifest directory: ${K8S_DIR}" >&2
  exit 1
fi

if [[ -z "$DB_URL" ]]; then
  echo "Missing GAMBLY_ELECTRIC_DATABASE_URL env var" >&2
  exit 1
fi

if [[ -z "$ELECTRIC_SECRET" ]]; then
  echo "Missing GAMBLY_ELECTRIC_SECRET env var" >&2
  exit 1
fi

if grep -q "REPLACE_ME" "${K8S_DIR}/pv.yaml"; then
  echo "Manifest ${K8S_DIR}/pv.yaml still contains REPLACE_ME values." >&2
  echo "Configure the EFS file system and access point IDs before deploying." >&2
  exit 1
fi

kubectl apply -f "${K8S_DIR}/csidriver-efs.yaml"
kubectl apply -f "${K8S_DIR}/pv.yaml"
kubectl apply -f "${K8S_DIR}/pvc.yaml"

kubectl create secret generic gambly-electric-env \
  --namespace "$NAMESPACE" \
  --from-literal=DATABASE_URL="$DB_URL" \
  --from-literal=ELECTRIC_SECRET="$ELECTRIC_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "${K8S_DIR}/deployment.yaml"
kubectl apply -f "${K8S_DIR}/service.yaml"
kubectl apply -f "${K8S_DIR}/ingress.yaml"

kubectl rollout status deployment/gambly-electric -n "$NAMESPACE" --timeout=5m
kubectl get pods -n "$NAMESPACE" -l app=gambly-electric
kubectl get svc gambly-electric -n "$NAMESPACE"
kubectl get ingress gambly-ingress-electric -n "$NAMESPACE"
