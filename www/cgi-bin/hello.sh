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

for s in cam date time ext dir debug; do
    eval "$s="
done

saveIFS=$IFS
IFS='&'
for kv in ${QUERY_STRING:?`nultrap`}; do
    case $kv in
    cam=*|date=*|time=*|ext=*|dir=*|debug=*)
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

echo "QUERY_STRING=$QUERY_STRING"
echo "cam=$cam"
echo "date=$date"
echo "time=$time"
echo "ext=$ext"
echo "dir=$dir"
echo "debug=$debug"


fmtargs="-f ${ext:?`nultrap`}"
vcodecargs='-vcodec h264 -pix_fmt yuv422p -preset veryfast -crf 30'
acodecargs=
contenttype=
filterargs='-vf fps=12.5'

case $ext in
'flv')
    contenttype='video/x-flv'
    acodecargs='-ar 44100'
    ;;
'mkv')
    contenttype='video/x-matroska'
    fmtargs='-f matroska'
    ;;
'webm')
    contenttype='video/webm'
    vcodecargs=
    filterargs= # 12.5fps too much for real time webm encoding
    ;;
'mp4')
    contenttype='video/mp4'
    fmtargs='-f mp4 -frag_duration 10000000'
    ;;
*)
    contenttype=$(awk -v ext="$ext" '!/^ *#/ { if ($2 == ext) { print $1; exit; } }' /etc/mime.types) || true
    [ -z "$contenttype" ] && contenttype='application/octet-stream'
    ;;
esac
echo "fmtargs=$fmtargs"
echo "contenttype=$contenttype"

echo

cd "${dir:?`nultrap`}"

desiredfirst="$date/$cam-$time.dat"
epoch() {
    local f=${1:?`nultrap`}
    f=${f%.*}
    local t=${f##*/}
    t=${t:$((${#cam}+1))}
    f="${f%/*} $t"
    f=${f//-/:}
    date -d "$f" +%s
}

echo

encoder_started=

feed() {
    local infile=${1:?`nultrap`}
    local seekargs=
    if [ -n "${2}" -a x"${1:?`nultrap`}" != x"${2}" ]; then
        seekargs="-ss $((`epoch "$2"` - `epoch "$1"`))"
    fi
    local a=( ffmpeg -loglevel warning $seekargs -i "$infile" $filterargs -f avi -acodec pcm_s16le -vcodec rawvideo - )
    echo "${a[@]}"
    [ x"$debug" = x"" ] || a=( sleep 2 )
    if [ -z "$encoder_started" ]; then
        exec 0</dev/null
        >&5 echo "Content-type: ${contenttype:?`nultrap`}"
        >&5 echo ""
        headers_sent=x

        echo starting encoder
        set -- ffmpeg -loglevel warning -y -f avi -i - $vcodecargs $acodecargs ${fmtargs:?`nultrap`} -
        echo "$@"
        exec 4>/dev/null
        [ x"$debug" = x"" ] && exec 4> >("$@" >&5)
        encoder_started=x
        echo
    fi
	"${a[@]}" >&4
    echo done
}

shopt -s nullglob

prev=

while true; do
    f=
    echo "scanning directory; desiredfirst=$desiredfirst"
    for f in */"$cam"-*.*; do
        #echo "$f"
        if [[ "$desiredfirst" < "$f" ]]; then
            if [ -z "$prev" ]; then
                echo "oldest file '$f' is newer than desired"
                exit 0
            fi
            feed "$prev" "$desiredfirst"
            desiredfirst=$f
        	break 2
        fi
        # "$desiredfirst" >= "$f"
        prev=$f
    done

    if [ -z "$f" ]; then
        echo "next file does not exist yet. sleeping..."
        sleep 10
    else
        echo "feeding the last file"
        feed "$f" "$desiredfirst"
        prev=$f
        break
    fi
done

while true; do
    f=
    g=
    echo "scanning directory; prev=$prev"
    for f in */"$cam"-*.*; do
        #echo "$f"
        if [[ "${prev:?`nultrap`}" < "$f" ]]; then
            feed "$f" "$f"
            prev=$f
            g=x
        fi
    done

    if [ -z "$g" ]; then
        echo "next file does not exist yet. sleeping..."
        sleep 10
    fi
done

exit 0
