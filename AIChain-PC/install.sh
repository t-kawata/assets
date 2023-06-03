#!/bin/bash
LOOP="/mnt/loop"
ISO=$(ls -l | grep "\.iso$" | awk '{print $9}')
CDIR=$(pwd)
# TARGET=${CDIR%?}2
TARGET=${CDIR}

mloop ${ISO}

sleep 3

echo "---"
echo "Start install os files to ${TARGET} ..."
echo "---"

sleep 2

# sudo cp -r ${LOOP}/EFI ${TARGET}/
# sudo cp -r ${LOOP}/boot ${TARGET}/
# sudo cp -r ${LOOP}/porteus ${TARGET}/

sudo rsync -av --progress ${LOOP}/EFI ${TARGET}/
sudo rsync -av --progress ${LOOP}/boot ${TARGET}/
sudo rsync -av --progress ${LOOP}/porteus ${TARGET}/

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
