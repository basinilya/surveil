#!/bin/bash

echo "generating some test data..."
for ((i=0;i<4;i++)); do ffmpeg -loglevel warning -y -f lavfi -i testsrc=s=720x576:r=12:d=4 -pix_fmt yuv422p -vf "drawtext=fontfile=/usr/share/fonts/TTF/DejaVuSans.ttf:boxcolor=0x000000AA:box=1:fontsize=24:y=line_h:fontcolor='white':text='$i'" test$i.mkv; done
echo "done"

fn_concat_init() {
    echo "fn_concat_init"
    concat_pls=`mktemp -u -p . concat.XXXXXXXXXX.txt`
    concat_pls="${concat_pls#./}"
    echo "concat_pls=${concat_pls:?}"
    mkfifo "${concat_pls:?}"
    echo
}

fn_concat_feed() {
    echo "fn_concat_feed ${1:?}"
    {
        >&2 echo "removing ${concat_pls:?}"
        rm "${concat_pls:?}"
        concat_pls=
        >&2 fn_concat_init
        echo 'ffconcat version 1.0'
        echo "file '${1:?}'"
        echo "file '${concat_pls:?}'"
    } >"${concat_pls:?}"
    echo
}

fn_concat_end() {
    echo "fn_concat_end"
    {
        >&2 echo "removing ${concat_pls:?}"
        rm "${concat_pls:?}"
        # not writing header.
    } >"${concat_pls:?}"
    echo
}

fn_concat_init

echo "launching ffmpeg..."
#timeout 60s ffplay -loglevel warning "${concat_pls:?}" &
timeout 60s ffmpeg -y -re -loglevel warning -i "${concat_pls:?}" -pix_fmt yuv422p all.mkv &

ffplaypid=$!

fn_concat_feed test0.mkv
fn_concat_feed test1.mkv
fn_concat_feed test2.mkv
fn_concat_feed test3.mkv

fn_concat_end

wait "${ffplaypid:?}"

echo "encoding done"
