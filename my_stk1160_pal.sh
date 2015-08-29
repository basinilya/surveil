#!/bin/bash
(
/usr/bin/v4l2-ctl -d "${DEVNAME:?}" -s PAL
) 2>&1 | logger -t my_stk1160_pal
