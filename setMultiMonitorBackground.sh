#!/bin/bash

# This script creates an image to span multiple monitors under Cinnamon
# It receives only one parameter which can be
# - A single file name : The script resizes and shaves the image to fit the screeens
# - A directory with potential files: the script selects randomly one file per monitor.
#
# Note: Files are scaled and shaved to fit the display area without loosing aspect radio.
#
#Requires:
#  ImageMagick
#  xrandr
#
# Author: Raul Suarez
# https://www.usingfoss.com/

#====== VALIDATE DEPENDENCIES ===

command -v gsettings >/dev/null 2>&1 || { echo >&2 "This script only works on systems which rely on gsettings.  Aborting."; exit 1; }
command -v xrandr >/dev/null 2>&1 || { echo >&2 "This script only works on systems which rely on xrandr.  Aborting."; exit 1; }
command -v identify >/dev/null 2>&1 || { echo >&2 "Please install 'imagemagick'.  Aborting."; exit 1; }

#====== GLOBAL VARIABLES ===

PARAM="${1}"
VALID=1

OUTIMG=/home/papa/.cinnamon/backgrounds/multiMonitorBackground.jpg

MONITORS=()
SCREENGEOMETRY=""

#====== FUNCTIONS ===

showHelp () {
    echo 'Usage: multiMonitorBackground [IMAGEFILE] | [IMAGEDIRECTORY]

This script creates an image to span multiple monitors under Cinnamon
It receives only one parameter which can be
- A single file name : The script resizes and shaves the image to fit the screeens
- A directory with potential files: the script selects randomly one file per monitor.
    
Examples
  setMultimonitorBackground mypicture.jpg
 
  setMultimonitorBackground "~/Pictures"
    
Note: Files are scaled and shaved to fit the display area without loosing aspect radio.
    
Requires:
  ImageMagick
  xrandr
    
Author: Raul Suarez
https://www.usingfoss.com/
'

}
isParameterValid () {
    if [ -f "${PARAM}" ]; then
        identify "${PARAM}" &>> /dev/null
        VALID=$?
    elif [ -d "${PARAM}" ]; then
        cd "${PARAM}"
        [ $(ls *.jpg *.png 2>/dev/null | wc -l) -gt 0 ]
        cd - &>> /dev/null
        VALID=$?
    else
        VALID=1
    fi
    return ${VALID}
}

getScreenGeometry () {
    SCREENGEOMETRY=$(xrandr | grep "Screen 0: " | sed "s/.*current \([0-9]*\) x \([0-9]*\).*/\1x\2/")
}

getMonitorsGeometry () {
    local MONITOR
    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")

    for MONITOR in $(xrandr --listmonitors | grep "^ [0-9]" | cut -s -d " " -f 4)
    do
        VARARRAY=($(echo ${MONITOR} | tr '/' '\n' | tr 'x' '\n' | tr '+' '\n'))
        MONITORS+=($(echo ${VARARRAY[0]}x${VARARRAY[2]} +${VARARRAY[4]}+${VARARRAY[5]}))
    done
    IFS=$SAVEIFS
}

assembleBackgroundImage () {
    local MONITOR
    local TEMPIMG=$(mktemp --suffix=.jpg -p /tmp tmpXXX)
    local TEMPOUT=$(mktemp --suffix=.jpg -p /tmp tmpXXX)

    # Creates the blank base image
    convert -size ${SCREENGEOMETRY} xc:skyblue ${TEMPOUT}

    # From the directory select as many random files as there are monitors
    NUMMONITORS=${#MONITORS[@]}
    FILES=($(ls *.jpg *.png 2>/dev/null | sort -R | tail -n ${NUMMONITORS} | sed "s/\n/ /"))

    i=0
    for MONITOR in "${MONITORS[@]}"
    do
        GEOMETRY=$(echo ${MONITOR} | cut -s -d " " -f 1)
        OFFSET=$(echo ${MONITOR} | cut -s -d " " -f 2)
        convert "${FILES[$((i++))]}" -auto-orient -scale ${GEOMETRY}^ -gravity center -extent ${GEOMETRY} ${TEMPIMG}
        composite -geometry ${OFFSET} ${TEMPIMG} ${TEMPOUT} ${TEMPOUT}
    done
    rm "${TEMPIMG}"
    mv "${TEMPOUT}" "${OUTIMG}"
}

setBackground () {
gsettings set org.cinnamon.desktop.background picture-options "spanned"
gsettings set org.cinnamon.desktop.background picture-uri "file://$(readlink -f ${OUTIMG})"
}

expandSingleImage () {
    FILE="${1}"
    convert "${FILE}" -auto-orient -scale ${SCREENGEOMETRY}^ -gravity center -extent ${SCREENGEOMETRY} "${OUTIMG}"
}

assembleOneImagePerMonitor () {
    cd "${PARAM}"

    getMonitorsGeometry
    assembleBackgroundImage
    cd - &>> /dev/null
}

#====== MAIN BODY OF THE SCRIPT ===

isParameterValid
if [ ${VALID} -eq 0 ]; then
    getScreenGeometry
    [ -f "${PARAM}" ] && expandSingleImage "${PARAM}"
    [ -d "${PARAM}" ] && assembleOneImagePerMonitor "${PARAM}"
    [ -f "${OUTIMG}" ] && setBackground
else
    showHelp
    exit 1
fi

