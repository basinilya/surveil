#!/bin/bash



fn_tailf() {
  set -e
  bs0=${BASH_SOURCE[0]}
  UNTRAP=${bs0%/*}/../rewritemap/untrap
  f=${1:?}
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
            #exec <&4 cat
            ;;
    esac
    $fn_tailf__pre
    exec <&4 tail --pid=${inotifywait_pid} -c +1 -f
}

