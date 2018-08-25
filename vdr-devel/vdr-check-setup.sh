#!/bin/sh

cfg=/var/lib/vdr/channels.conf
if [ ! -s $cfg ] ; then
    echo "$cfg is not valid, use \"w_scan -t 3 -o 21\" from the w_scan package to create one." >&2
    exit 2
else
    chown vdr:video $cfg && chmod 644 $cfg
fi
