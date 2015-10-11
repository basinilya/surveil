#!/bin/bash

headers_sent=

set -e
set -o pipefail
function errtrap {     es=$?;     echo "ERROR line $1: Command exited with status $es.">&2; }; trap 'errtrap $LINENO' ERR

exec 5>&1 1>&2
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

cam=
date=
time=
ext=
debug=

saveIFS=$IFS
IFS='&'
for kv in ${QUERY_STRING:?}; do
    case $kv in
    cam=*|date=*|time=*|ext=*|debug=*)
    cgi_decodevar "${kv#*=}"
    eval "${kv%%=*}=\$cgi_decodevar_val"
    ;;
    esac
done
IFS=$saveIFS

if [ x"$debug" != x"" ]; then
    exec 1>&5 2>&1
    echo "Content-type: text/plain"
    echo ""
fi

echo cam=$cam
echo date=$date
echo time=$time
echo ext=$ext
echo debug=$debug

fmtargs="-f ${ext:?}"
codecargs='-codec h264 -pix_fmt yuv422p -preset veryfast -crf 30'
contenttype=
filterargs='-vf fps=12.5'

case $ext in
'flv')
    contenttype='video/x-flv'
    ;;
'mkv')
    contenttype='video/x-matroska'
    fmtargs='-f matroska'
    ;;
'webm')
    contenttype='video/webm'
    codecargs=
    filterargs= # 12.5fps too much for real time webm encoding
    ;;
'mp4')
    contenttype='video/mp4'
    fmtargs='-f mp4 -frag_duration 10000000'
    ;;
esac
echo "fmtargs=$fmtargs"
echo "contenttype=$contenttype"

echo

cd /var/cache/surveil/cam

desiredfirst="$date/$cam-$time.mkv"
echo "desiredfirst=$desiredfirst"
epoch() {
    local f=${1:?}
    f=${f%.*}
    f="${f%/*} ${f: -8}"
    f=${f//-/:}
    date -d "$f" +%s
}
#epoch $desiredfirst

echo
#exit 0

encoder_started=

feed() {
    local infile=${1:?}
    local seekargs=
    if [ -n "${2}" -a x"${1:?}" != x"${2}" ]; then
        seekargs="-ss $((`epoch "$2"` - `epoch "$1"`))"
    fi
    local a=( ffmpeg -loglevel warning $seekargs -i "$infile" $filterargs -f avi -acodec pcm_s16le -vcodec rawvideo - )
    echo "${a[@]}"
    [ x"$debug" = x"" ] || a=( sleep 2 )
    if [ -z "$encoder_started" ]; then
        exec 0</dev/null
        >&5 echo "Content-type: ${contenttype:?}"
        >&5 echo ""
        headers_sent=x

        echo starting encoder
        set -- ffmpeg -loglevel warning -y -f avi -i - $codecargs ${fmtargs:?} -
        echo "$@"
        exec 4>/dev/null
        [ x"$debug" = x"" ] && exec 4> >("$@" >&5)
        encoder_started=x
        echo
    fi
	"${a[@]}" >&4
    echo done
}

while true; do
prev=
shopt -s nullglob
f=
for f in */"$cam"-*.mkv; do
    #echo "$f"
    if [[ "$desiredfirst" < "$f" ]]; then
        [ -z "$prev" ] && break 2
        feed "$prev" "$desiredfirst"
        desiredfirst=$f
	#exit 0
	continue 2
    fi
    #echo "$f"
    prev=$f
done
[ -z "$f" ] || feed "$f" "$desiredfirst"
break
done

exit 0
