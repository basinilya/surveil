#!/bin/bash


set -e

fn_islastfile() {

shopt -s nullglob dotglob

f=${1:?}
[ ! -d "$f/" ] || return 1

name=${f##*/}
dir=.
if [ x"$name" != x"$f" ]; then
  dir=${f%/*}/
fi

cd -- "$dir"


v=continue

for x in *; do
    if [ x"$x" = x"$name" ]; then
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

while read -r u; do
    fn_islastfile "$u" && r=yes || r=no
    printf '%s\n' "$r"
done

#fn_islastfile "$@"
