#!/bin/bash
set -euo pipefail
exec /bin/bash "$(dirname "$0")/build-native.sh" "$@"
