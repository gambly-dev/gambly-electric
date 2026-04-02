#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-dev}"
VALUES_FILE="k8s/values-${ENVIRONMENT}.env"
NAMESPACE="gambly-${ENVIRONMENT}"

if [[ ! -f "$VALUES_FILE" ]]; then
  echo "Missing values file: ${VALUES_FILE}" >&2
  exit 1
fi

if grep -q "REPLACE_ME" "$VALUES_FILE"; then
  echo "${VALUES_FILE} still contains REPLACE_ME values." >&2
  echo "Configure the EFS file system and access point IDs before deploying." >&2
  exit 1
fi

# Load environment-specific values for template substitution
set -a
source "$VALUES_FILE"
set +a

# Render templates
RENDERED_DIR=$(mktemp -d)
trap 'rm -rf "$RENDERED_DIR"' EXIT
for tpl in k8s/base/*.yaml; do
  envsubst < "$tpl" > "${RENDERED_DIR}/$(basename "$tpl")"
done

# Apply storage resources
kubectl apply -f "${RENDERED_DIR}/csidriver-efs.yaml"
kubectl apply -f "${RENDERED_DIR}/pv.yaml"
kubectl apply -f "${RENDERED_DIR}/pvc.yaml"

# Create secret — accepts either a .env file or individual env vars
if [[ -f .env ]]; then
  kubectl create secret generic gambly-electric-env \
    --namespace "$NAMESPACE" \
    --from-env-file=.env \
    --dry-run=client -o yaml | kubectl apply -f -
else
  DB_URL="${GAMBLY_ELECTRIC_DATABASE_URL:-}"
  ELECTRIC_SECRET_VAL="${GAMBLY_ELECTRIC_SECRET:-}"

  if [[ -z "$DB_URL" || -z "$ELECTRIC_SECRET_VAL" ]]; then
    echo "No .env file found and GAMBLY_ELECTRIC_DATABASE_URL / GAMBLY_ELECTRIC_SECRET not set" >&2
    exit 1
  fi

  kubectl create secret generic gambly-electric-env \
    --namespace "$NAMESPACE" \
    --from-literal=DATABASE_URL="$DB_URL" \
    --from-literal=ELECTRIC_SECRET="$ELECTRIC_SECRET_VAL" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# Apply workload resources
kubectl apply -f "${RENDERED_DIR}/deployment.yaml"
kubectl apply -f "${RENDERED_DIR}/service.yaml"
kubectl apply -f "${RENDERED_DIR}/ingress.yaml"

kubectl rollout status deployment/gambly-electric -n "$NAMESPACE" --timeout=5m
kubectl get pods -n "$NAMESPACE" -l app=gambly-electric
kubectl get svc gambly-electric -n "$NAMESPACE"
kubectl get ingress gambly-ingress-electric -n "$NAMESPACE"
