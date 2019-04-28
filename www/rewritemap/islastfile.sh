#!/bin/bash

set -e

fn_islastfile() {

shopt -s nullglob dotglob

f=${1:?}
name=${f##*/}
dir=.
if [ x"$name" != x"$f" ]; then
  dir=${f%/*}/
fi

cd -- "$dir"


v=continue

found=
for x in *; do
    if [ x"$x" = x"$name" ]; then
        found=x
        v="return 1"
        continue
    fi
    $v
done
if [ x"$v" = x"continue" ]; then
    return 1
fi
return 0
}

fn_islastfile "$@"
