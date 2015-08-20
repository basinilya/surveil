#!/bin/bash
(
echo aaa
/usr/bin/v4l2-ctl -d /dev/video0 -s PAL
) 2>&1 | logger -t my_stk1160_pal
