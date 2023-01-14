#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$( cd "$( dirname "$0" )" && pwd )"

$CURRENT_DIR/../installer/docker-compose.sh update
