#!/bin/bash

spinner() {
    local i sp n
    sp='/-\|'
    n=${#sp}
    printf ' '
    while sleep 0.1; do
        printf "%s\b" "${sp:i++%n:1}"
    done
}

LOOP="/mnt/loop"
ISO=$(ls -l | grep "\.iso$" | awk '{print $9}')
CDIR=$(pwd)
# TARGET=${CDIR%?}2
TARGET=${CDIR}

mloop ${ISO}

sleep 3

echo "---"
echo "Start install OS files to ${TARGET} ..."
echo "---"

spinner &

sleep 2

cp -r ${LOOP}/EFI ${TARGET}/
cp -r ${LOOP}/boot ${TARGET}/
cp -r ${LOOP}/porteus ${TARGET}/

kill "$!"

sleep 1

echo "---"
echo "Now you have all os files in ${TARGET} like below."
echo "---"

ls -l ${TARGET}

echo "---"

sleep 2

echo "---"
echo "Start settings of boot ..."
echo "---"

sleep 2

sudo sh ${TARGET}/boot/Porteus-installer-for-Linux.com

echo "---"
echo "Completed all instaling proceses !!"
echo "---"

sleep 1

# echo "---"
# echo "Start settings to protect boot device ..."
# echo "---"

# sleep 2

# chmod -R a-w ${TARGET}

# sleep 1

echo "---"
echo "Start unmounting ..."
echo "---"

sleep 1

uloop

sleep 1

sudo rm -rf /mnt/loop

echo "---"
echo "END."
echo "---"

sleep 5

exit 0
