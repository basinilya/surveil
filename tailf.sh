#!/bin/bash
exec 4>&1
exec 1> >(exec logger -t tailf.sh >/dev/null 2>&1 4>&- ) 2>&1
THISDIR=`cd "\`dirname \"$0\"\`" && pwd`
exec -- "$THISDIR/fm" repl_getclip_backend
