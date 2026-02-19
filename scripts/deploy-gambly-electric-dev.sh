#!/usr/bin/env bash
set -euo pipefail

exec "$(dirname "$0")/deploy-gambly-electric.sh" dev
