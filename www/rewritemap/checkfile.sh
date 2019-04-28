#!/bin/bash

set -e

fn_aaa() {
  # aa
  exec 0<"${f:?}"
  LC_ALL=en_US.UTF-8 inotifywait -e close_write -- /proc/self/fd/0 2>&1 | {
    read -r h
    read -r x
    case $x in
    'Watches established.')
        :
        ;;
    *)
        >&2 printf "%s\n%s" "$h" "$x"
        exit 1
        ;;
    esac
    modes=`lsof -Fa -- "${f:?}"`
    case $modes in
        *$'\naw'*)
            >&2 echo opened for writing
    esac
    #tail -c +1 -f -- "${f:?}" &
  }
}

fn_bbb() {
    lsof -- "${f:?}" | while read -r c pid u fd t d s i name; do
      case $fd in
      *w*)
      echo tail -c +1 -f --pid=$pid -- "$f"
      break;
      ;;
      esac
    done
}


f=${1:?}
fn_aaa
