#!/bin/bash
#Start QJackCtl Persistent Patches
/usr/bin/qjackctl &
wait 5 &
#Start Liquidsoap
liquidsoap /home/rd/imports/APPS/radio.liq
#Start StereoTool
#/home/rd/imports/APPS/stereo_tool_gui_jack_64_1030
exit 0
