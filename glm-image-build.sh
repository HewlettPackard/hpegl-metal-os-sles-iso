#!/bin/bash
# (C) Copyright 2021-2022 Hewlett Packard Enterprise Development LP
#
# This script will repack SLES .ISO file for a GLM
# SLES install service that uses Virtual Media
# to get the install started.

# The following changes are being made to the SLES .ISO:
#   (1) configure to use an autoinst.xml file on the iLO vmedia-cd and to
#       pull the RPM packages (stage2) over vmedia
#   (2) setup for a text based install (versus a GUI install)
#   (3) set up the console to the iLO serial port (/dev/ttyS1)

# The SLES .ISO is configured to use an autoinst.xml file on the iLO
# vmedia-cd by adding the 'autoyast=usb:///glm-autoinst.xml' option in
# GRUB (used in UEFI) and isolinux (used in BIOS) configuration
# files. This option configures SLES installer to pull the
# autoinst file from the root of the cdrom at /glm-autoinst.xml.
# This autoinst option is setup by modifying the following files
# on the .ISO:
#   boot/x86_64/loader/isolinux.cfg for BIOS
#   EFI/BOOT/grub.cfg for UEFI

# Usage:
#  glm-image-build.sh -i <sles.iso> -v <version> -o <glm-customizied-sles.iso>

# command line options          | Description
# ----------------------------- | -----------
# -i <sles.iso>                 | Input SLES .ISO filename
# -v <version>                  | SLES version number x.y
# -o <glm-customizied-sles.iso> | Output GLM SLES .ISO file

set -exuo pipefail

which xorriso > /dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "xorriso not found. Please install."
  exit -1
fi

which implantisomd5 > /dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "implantisomd5 not found. Please install."
  exit -1
fi

INPUT_ISO_FILENAME=""
CUSTOM_ISO_FILENAME=""
SLES_VER=""
# parse command line parameters
while getopts "i:o:v:" opt
do
    case $opt in
        i) INPUT_ISO_FILENAME=$OPTARG
            if [[ ! -f $INPUT_ISO_FILENAME ]]
            then
                echo "ERROR missing image file $INPUT_ISO_FILENAME"
                exit -1
            fi
            ;;
        o) CUSTOM_ISO_FILENAME=$OPTARG ;;
        v) SLES_VER=$OPTARG ;;
    esac
done

if [ -z "$INPUT_ISO_FILENAME" -o -z "$CUSTOM_ISO_FILENAME" -o -z "$SLES_VER" ]; then
   echo "Usage: $0 -i <sles.iso> -v <version> -o <glm-customizied-sles.iso>"
   exit 1
fi

# Generate unique ID for use as the uploaded file name.
ID=$RANDOM
YYYYMMDD=$(date '+%Y%m%d')

# get the SLES version string from the SLES .ISO file
SLES_ISO_LABEL=$(isoinfo -d -i $INPUT_ISO_FILENAME |& grep "^Volume id:" | sed -e "s/Volume id: //")
echo "SLES version string found in $INPUT_ISO_FILENAME is $SLES_ISO_LABEL"

UEFI_CFG_FILE=EFI/BOOT/grub.cfg

xorriso -osirrox on -indev $INPUT_ISO_FILENAME -extract ${UEFI_CFG_FILE} ${UEFI_CFG_FILE}

if [ ! -f "${UEFI_CFG_FILE}" ]; then
  echo "did not find ${UEFI_CFG_FILE} on <sles-iso-filename>"
  exit -1
fi

# Make the extracted file writable (xorriso makes it read-only when extracted)
chmod -R u+w EFI

###################################################
# start the UEFI_CFG_FILE file modifications

# Make install to be the default choice
sed -i "s/^default=.*$/default=1/" ${UEFI_CFG_FILE}

# Replace the splash=silent kernel command line option, with:
#   * console=ttyS1,115200
#   * autoyast=usb:///glm-autoinst.xml
# removing the splash=silent will enable the user can watch kernel loading
# and use to triage any problems
sed -i "s/splash=silent/console=ttyS1,115200 autoyast=usb:\/\/\/glm-autoinst.xml/" ${UEFI_CFG_FILE}

# Change the timeout from 60 seconds to 5
sed -i "s/^  timeout=.*$/  timeout=5/" ${UEFI_CFG_FILE}

# end the UEFI_CFG_FILE file modifications
###################################################

# Create new ISO file with modified CFG
xorriso -indev $INPUT_ISO_FILENAME -outdev ${CUSTOM_ISO_FILENAME} -boot_image isohybrid keep -update ${UEFI_CFG_FILE} ${UEFI_CFG_FILE}

# Implant an MD5 checksum into the image. Without performing this step,
# image verification check (the rd.live.check option in the boot
# loader configuration) will fail and you will not be able to continue
# with the installation.
MD5_ISO="implantisomd5 ${CUSTOM_ISO_FILENAME}"
echo $MD5_ISO
$MD5_ISO

rm -rf EFI
