#!/bin/bash

exec 2> >(logger -t cgi)

shopt -s nullglob

>&2 echo "QUERY_STRING=$QUERY_STRING"

for d in /var/cache/fm/*; do
    >&2 echo "checking $d"
    case $QUERY_STRING in
    "dir=${d}&"*)
    exec -- ${0%/*}/hello.sh "$@"
    ;;
    esac
done
>&2 echo failed
exit 1
