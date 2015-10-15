#!/bin/bash

while true; do
    rc=0
    rsync -rv --append $(for i in 1 0 -1; do echo --exclude=`date -d "+${i}hour" +/\%Y\%m\%d/"*"-\%H-"??-??.*"`; done) \
        rsync://localhost:10873/surveillance/cam/ /var/cache/surveil/cam/ || rc=$?
    [ $rc = 11 ] || break
    /home/il/surveil/cleandisk --dir /var/cache/surveil/cam --minfree $((90*1000000))
done
