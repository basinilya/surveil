#!/bin/bash

THISDIR=`cd "\`dirname \"$0\"\`" && pwd`

clean=( "$THISDIR/cleandisk" --dir /var/cache/surveil/cam --lockdir --minfree $((90*1000000)) )

"${clean[@]}"

trap 'kill $!' EXIT

{
    renice +10 $BASHPID
    while true; do
        "${clean[@]}" >/dev/null
        sleep 2
    done
} &

while true; do
    rc=0

#        --quiet \

    rsync \
        -v --progress \
        -r --times --append $(for i in +1 +0 -1; do echo --exclude=`date -d "${i}hour" +/\%Y\%m\%d/"*"-\%H-"??-??.*"`; done) \
        rsync://localhost:10873/surveillance/cam/ /var/cache/surveil/cam/ || rc=$?

    echo rc=$rc

    [ $rc = 0 ] && break
    [ $rc = 20 ] && kill -INT $$
    sleep 60
done
