#!/bin/bash

# Set RTC wakeup for next VDR timer event

shopt -s extglob

# Check timestamp set by shutdown script.
nexttimer=$( cat /var/run/vdr/next-timer 2>/dev/null )
rm -f /var/run/vdr/next-timer

if [[ $nexttimer != +([0-9]) ]] ; then
    # Next timer timestamp not set by shutdown script or bogus,
    # try to get it via SVDRP.
    nexttimer=$( svdrpsend NEXT abs 2>/dev/null | \
        sed -rne 's/^250[[:space:]]+[0-9]+[[:space:]]+([0-9]+).*/\1/p' )
fi

# TODO: nexttimer may be in the past if there's an ongoing recording
# (see svdrpsend HELP NEXT). In that case we should set *something* or
# the box won't autowakeup at all
if [[ $nexttimer && $nexttimer -gt $( date +%s ) ]] ; then
    [[ -f /etc/sysconfig/vdr ]] && . /etc/sysconfig/vdr
    when=$(( $nexttimer - ${WAKEUP_BEFORE_RECORDING:-10} * 60 ))
    hrwhen=$( date -d "1970-01-01 $when sec UTC" )
    echo "Setting wakeup time for next recording: $hrwhen"
    /usr/bin/rtcwake -m no -t $when >/dev/null
fi
