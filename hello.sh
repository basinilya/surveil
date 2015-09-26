#!/bin/bash

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

echo "Content-type: text/plain"
# "video/webm"
echo ""

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
prev=
for f in */"$cam"-*.mkv; do
    if [[ "$desiredfirst" < "$f" ]]; then
        echo "$f"
    fi
    #echo "$f"
    prev=$f
done

exit 0
