#!/bin/bash

headers_sent=

switchplain() {
    exec 1>&5 2>&1
    echo "Content-type: text/plain"
    echo ""
    headers_sent=x
}

set -e
set -o pipefail

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
exec 5>&1 1>&2
trap 'errtrap $LINENO' ERR
exec 1> >(logger -t cgi) 2>&1

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

for s in x_on x_off; do
    eval "$s="
done

saveIFS=$IFS
IFS='&'
for kv in ${QUERY_STRING:?`nultrap`}; do
    case $kv in
    x_on=*|x_off=*)
    eval "v=\$${kv%%=*}"
    if [ -z "$v" ]; then
        cgi_decodevar "${kv#*=}"
        eval "${kv%%=*}=\$cgi_decodevar_val"
    fi
    ;;
    esac
done
IFS=$saveIFS

switchplain

x=${x_on:+1}${x_off:+0}

/usr/bin/ssh -oUserKnownHostsFile=/srv/www/wwwrun/known_hosts -oIdentityFile=/srv/www/wwwrun/zzz-nas.id_rsa root@smarthome "/usr/local/bin/heatpower.sh $x" || true

printf '%q\n' "$@"
echo
echo "QUERY_STRING=$QUERY_STRING"
/usr/bin/id
echo "x=$x"
env
echo
timeout 2s cat || true
