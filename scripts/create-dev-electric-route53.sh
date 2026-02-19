#!/usr/bin/env bash
set -euo pipefail

HOSTED_ZONE_ID="Z02597487LUMGMG2ITHR"
RECORD_NAME="dev-electric.gambly.com."
CHANGE_BATCH_FILE="k8s/dev/route53-dev-electric-create.json"

existing_record_count="$(
  aws route53 list-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --query "length(ResourceRecordSets[?Name=='${RECORD_NAME}'])" \
    --output text
)"

if [[ "$existing_record_count" != "0" ]]; then
  echo "Record ${RECORD_NAME} already exists; refusing to modify existing DNS records." >&2
  exit 1
fi

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "file://${CHANGE_BATCH_FILE}"
