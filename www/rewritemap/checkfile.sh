#!/bin/bash

set -e

UNTRAP=${0%/*}/untrap

#$UNTRAP --sig=INT=DEFAULT -- bash -c 'trap "echo got signal" INT; sleep 20' &


fn_aaa() {
  exec 4<"${f:?}"

  set -- inotifywait -e close_write -- /proc/self/fd/4
  coproc {
    # tail won't reap children so forking a grandchild
    {
        read -r proceed || true
        LC_ALL=en_US.UTF-8 exec $UNTRAP --sig=INT=DEFAULT -- "$@" 2>&1
    } <&0 &
    echo $!
  }
  eval "exec 0<&${COPROC[0]} ${COPROC[0]}<&- 5>&${COPROC[1]} ${COPROC[1]}>&-; child_pid=$COPROC_PID"

    read -r inotifywait_pid
    trap "kill $inotifywait_pid" EXIT
    exec 5>&- # proceed
    wait $child_pid
    read -r h
    read -r x || true
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
            ;;
        *)
            >&2 echo not opened for writing
            kill ${inotifywait_pid}
            exec <&4 cat
            ;;
    esac
    exec <&4 tail --pid=${inotifywait_pid} -c +1 -f
}

f=${1:?}
fn_aaa
