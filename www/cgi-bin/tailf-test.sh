#!/bin/bash
set -e
set -o pipefail
bs0=${BASH_SOURCE[0]}
QUERY_STRING="file=${1:?}" "${bs0%/*}/tailf.sh" # | pv -B128 >/dev/null
