#!/bin/bash

set -e
set -o pipefail
function errtrap {     es=$?;     echo "ERROR line $1: Command exited with status $es.">&2; }; trap 'errtrap $LINENO' ERR

exec 5>&1 1> >(logger -t cgi) 2>&1

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

saveIFS=$IFS
IFS='&'
for kv in $QUERY_STRING; do
    case $kv in
    cam=*|date=*|time=*|ext=*)
    cgi_decodevar "${kv#*=}"
    eval "${kv%%=*}=\$cgi_decodevar_val"
    ;;
    esac
done
IFS=$saveIFS

echo cam=$cam
echo date=$date
echo time=$time
echo ext=$ext

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
    local a=( ffmpeg -loglevel warning $seekargs -i "$infile" -vf fps=12.5 -f yuv4mpegpipe -vcodec rawvideo - )
    echo "${a[@]}"
    if [ -z "$encoder_started" ]; then
        exec 0</dev/null
        >&5 echo "Content-type: video/x-flv"
        >&5 echo ""

        echo starting encoder
	set -- ffmpeg -loglevel warning -y -f yuv4mpegpipe -vcodec rawvideo -i - -codec h264 -pix_fmt yuv422p -preset veryfast -crf 30 -f flv -
	echo "$@"
        exec 4> >("$@" >&5)
	encoder_started=x
	echo
	"${a[@]}" >&4
    else
        "${a[@]}" | tail -n +2 >&4
    fi
    echo done
}

while true; do
prev=
for f in */"$cam"-*.mkv; do
    if [[ "$desiredfirst" < "$f" ]]; then
        [ -z "$prev" ] && break 2
        feed "$prev" "$desiredfirst"
	#exit 0
	desiredfirst=$f
	continue 2
    fi
    #echo "$f"
    prev=$f
done
feed "$f" "$f"
break
done

echo not found


exit 0
