#!/bin/bash


headers_sent=

status="500 Internal Error"

switchplain() {
    exec 1>&5 2>&1
    echo "Status: $status"
    echo "Content-type: text/plain"
    echo ""
    headers_sent=x
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


headers_sent=
set -e
set -o pipefail

key=$(cat /etc/apache2/tellwebmaster.key)
k=

saveIFS=$IFS
IFS='&'
for kv in ${QUERY_STRING:?`nultrap`}; do
    case $kv in
    k=*)
    eval "v=\$${kv%%=*}"
    if [ -z "$v" ]; then
        cgi_decodevar "${kv#*=}"
        eval "${kv%%=*}=\$cgi_decodevar_val"
    fi
    ;;
    esac
done
IFS=$saveIFS

if [ x"$k" != x"$key" -o x"$REQUEST_METHOD" != x"POST" ]; then
  switchplain
  echo "$status"
  exit 1
fi

message=$(
date
echo "remote: $REMOTE_ADDR:$REMOTE_PORT $HTTP_X_FORWARDED_FOR"
echo "user agent: $HTTP_USER_AGENT"
echo ""
cat
)

(
echo "========================"
echo "$message"
echo "========================"
) >>/var/log/tellwebmaster/tellwebmaster.log || true

echo "$message" | /usr/bin/mailx -s "posted via tellwebmaster script" basinilya@gmail.com

#status="200 OK"
status="201 Created"

switchplain

echo sent
