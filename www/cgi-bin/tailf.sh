#!/bin/bash

# Goals:
# - serve a growing file and don't send EOF until the writer closed the file
# - send EOF immediately after the writer closed the file
# tail, lsof, and inotifywait must be installed

switchplain() {
    exec 1>&5 2>&1
    echo "Status: 500 Internal Error"
    echo "Content-type: text/plain"
    echo ""
    headers_sent=x
}

fn_404() {
  exec 1>&5
  echo "Status: 404 Not Found"
  echo ""
  headers_sent=x
  exit 1
}

nultrap() {
    if [ -z "$headers_sent" ]; then
        switchplain
    fi
    echo "parameter null or not set"
}

errtrap() {
    es=$?
    if [ -z "$headers_sent" ]; then
        switchplain
    fi
    echo "ERROR line $1: Command exited with status $es.">&2
}
#This code for getting code from post data is from http://oinkzwurgl.org/bash_cgi and
#was written by Phillippe Kehi <phkehi@gmx.net> and flipflip industries

# (internal) routine to decode urlencoded strings
function cgi_decodevar()
{
    [ $# -ne 1 ] && return
    local v t h
    # replace all + with whitespace and append %%
    t="${1//+/ }%%"
    while [ ${#t} -gt 0 -a "${t}" != "%" ]; do
	v="${v}${t%%\%*}" # digest up to the first %
	t="${t#*%}"       # remove digested part
	# decode if there is anything to decode and if not at end of string
	if [ ${#t} -gt 0 -a "${t}" != "%" ]; then
	    h=${t:0:2} # save first two chars
	    t="${t:2}" # remove these
	    v="${v}"`echo -e \\\\x${h}` # convert hex to special char
	fi
    done
    # return decoded string
    cgi_decodevar_val="${v}"
    return
}

fn_tailf_main() {
  headers_sent=
  set -e
  set -o pipefail

  exec 5>&1 1>&2
  trap 'errtrap $LINENO' ERR
  exec 1> >(logger -t cgi) 2>&1

  for s in file debug; do
      eval "$s="
  done

  saveIFS=$IFS
  IFS='&'
  for kv in ${QUERY_STRING:?`nultrap`}; do
      case $kv in
      file=*|debug=*)
      eval "v=\$${kv%%=*}"
      if [ -z "$v" ]; then
          cgi_decodevar "${kv#*=}"
          eval "${kv%%=*}=\$cgi_decodevar_val"
      fi
      ;;
      esac
  done
  IFS=$saveIFS

  if [ x"$debug" != x"" ]; then
      switchplain
  fi

  id
  echo "QUERY_STRING=$QUERY_STRING"
  echo "file=$file"
  echo "debug=$debug"

  if [ x"$debug" = x"head" ]; then
      exit 0
  fi

  contenttype=`file -b --mime-type "$file"`
  hdr="Content-type: $contenttype"$'\n\n'
  fn_tailf__pre=fn_fn_tailf__pre
  fn_tailf "$file"
}

fn_lsof_old() {
  (
  set +o pipefail # to ignore SIGPIPE

  # when unavailable NFS share, lsof hangs unless '-b' is specified
  # however, passing names to `lsof -b` fails
  # This is why we have to filter lsof output
  # This approach will not cause auto-mounting, but it has the flaw that
  # the file won't be found if it was opened using an alternative path
  /usr/local/bin/lsof-suid -w -b -Fan | awk -v f="$1" '
    /^a/ { mode=$0; }
    /^n/ { if (f == substr($0,2) && index(mode,"w") >= 2) { success=1; exit; } }
    END { exit(!success); }'
  )
}

fn_lsof() {
  (
  set +o pipefail # to ignore SIGPIPE

  /usr/local/bin/lsof-suid -w -Fan -- "$1" | grep 'a.*w' >/dev/null
  )
}

fn_tailf() {
  set -e
  bs0=${BASH_SOURCE[0]}
  UNTRAP=${bs0%/*}/../rewritemap/untrap
  f=${1:?}
  exec 14<"${f:?}" || fn_404

  set -- inotifywait -e close_write -- /proc/self/fd/14
  coproc {
    # tail won't reap children so forking a grandchild
    {
        read -r proceed || true
        LC_ALL=en_US.UTF-8 exec $UNTRAP --sig=INT=DEFAULT -- "$@" 2>&1
    } <&0 &
    echo $!
  }
  eval "exec 0<&${COPROC[0]} ${COPROC[0]}<&- 15>&${COPROC[1]} ${COPROC[1]}>&-; child_pid=$COPROC_PID"

    read -r inotifywait_pid
    trap "kill $inotifywait_pid" EXIT
    exec 15>&- # proceed
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
    if fn_lsof "${f:?}"; then
            >&2 echo file is opened for writing
    else 
            >&2 echo file not opened for writing
            kill ${inotifywait_pid}
            #exec <&14 cat
    fi
    $fn_tailf__pre
    exec <&14 tail --pid=${inotifywait_pid} -c +1 -f
}

fn_fn_tailf__pre() {
  exec 1>&5
  printf %s "$hdr"
}

if [[ "$0" = "${BASH_SOURCE[0]}" ]]; then
  fn_tailf_main "$@"
fi

