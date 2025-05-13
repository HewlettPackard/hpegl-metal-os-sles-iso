#!/bin/bash
# (C) Copyright 2018-2022 Hewlett Packard Enterprise Development LP

# This is the top level build script that will take a SLES install ISO and
# generate a SLES service.yml file that can be imported as a Host imaging
# service into a GreenLake Metal portal.

# glm-build-image-and-service.sh does the following steps:
# * process command line arguements.
# * Customize the SLES .ISO so that it works for GLM.  Run: glm-image-build.sh.
# * Generate GLM service file that is specific to $SLES_VER. Run: glm-service-build.sh.

# glm-build-image-and-service.sh usage:
# glm-build-image-and-service.sh -i <sles-iso-filename> -o <glm-custom-sles-iso>
#    -v <sles-version-number> -p <image-url-prefix> -s <glm-yml-service-file>

# command line options       | Description
# -------------------------- | -----------
# -i <sles-iso-filename>     | local filename of the standard SLES .ISO file
#                            | that was already downloaded. Used as input file.
# -------------------------- | -----------
# -v <sles-version-number>   | a x.y SLES version number.  Example: -v 15SP3
# -------------------------- | -----------
# -o <glm-custom-sles-iso>   | local filename of the GLM-modified SLES .ISO file
#                            | that will be output by the script.  This file should
#                            | be uploaded to your web server.
# -------------------------- | -----------
# -p <image-url-prefix>      | the beginning of the image URL (on your web server).
#                            | Example: -p http://192.168.1.131.  The GLM service .YML
#                            | will assume that the image file will be available at
#                            | a URL constructed with <image-url-prefix>/<glm-custom-sles-iso>.
# -------------------------- | -----------
# -s <glm-yml-service-file>  | local filename of the GLM .YML service file that
#                            | will be output by the script.  This file should
#                            | be uploaded to the GLM portal.
# -------------------------- | -----------

# NOTE: The users of this script are expected to copy the
# <glm-custom-sles-iso> .ISO file to your web server such
# that the file is available at this constructed URL:
# <image-url-prefix>/<glm-custom-sles-iso>

# If the image URL cannot be constructed with this
# simple mechanism then you probably need to customize
# this script for a more complex URL costruction.

# This script calls glm-image-build.sh, which needs the
# following packages to be installed:
#
# on Debian/Ubuntu:
#  sudo apt install genisoimage isomd5sum syslinux-utils

set -euo pipefail

GLM_YML_SERVICE_TEMPLATE=$(mktemp /tmp/glm-service.cfg.XXXXXXXXX)

# required parameters
SLES_ISO_FILENAME=""
GLM_CUSTOM_SLES_ISO=""
SLES_VER=""
IMAGE_URL_PREFIX=""
GLM_YML_SERVICE_FILE=""

while getopts "i:v:o:p:s:" opt
do
    case $opt in
        # required parameters
        i) SLES_ISO_FILENAME=$OPTARG ;;
        v) SLES_VER=$OPTARG ;;
        o) GLM_CUSTOM_SLES_ISO=$OPTARG ;;
        p) IMAGE_URL_PREFIX=$OPTARG ;;
        s) GLM_YML_SERVICE_FILE=$OPTARG ;;
     esac
done

# Check that required parameters exist.
if [ -z "$SLES_ISO_FILENAME" -o \
     -z "$GLM_CUSTOM_SLES_ISO" -o \
     -z "$SLES_VER" -o \
     -z "$IMAGE_URL_PREFIX" -o \
     -z "$GLM_YML_SERVICE_FILE" ]; then
  echo "script usage: $0 -i sles-iso -v sles-version" >&2
  echo "              -o glm-custom-sles-iso -p http-prefix -s glm-yml-service-file" >&2
  exit 1
fi

if [[ ! -f $SLES_ISO_FILENAME ]]; then
  echo "ERROR missing ISO image file $SLES_ISO_FILENAME"
  exit 1
fi

# The clean function cleans up any lingering files
# that might be present when the script exits.
clean() {
   rm -f $GLM_YML_SERVICE_TEMPLATE
}

trap clean EXIT

# if the GLM customized SLES .ISO has not aleady been generated.
if [ ! -f $GLM_CUSTOM_SLES_ISO ]; then
   # Customize the SLES .ISO so that it works for GLM.
   GEN_IMAGE="./glm-image-build.sh \
      -i $SLES_ISO_FILENAME \
      -v $SLES_VER \
      -o $GLM_CUSTOM_SLES_ISO"
   echo $GEN_IMAGE
   $GEN_IMAGE
fi

sed -e "s/SLES_VERSION/$SLES_VER/g" glm-service.yml.template > $GLM_YML_SERVICE_TEMPLATE

# Generate HPE GLM service file.
YYYYMMDD=$(date '+%Y%m%d')
GEN_SERVICE="./glm-service-build.sh \
  -s $GLM_YML_SERVICE_TEMPLATE \
  -o $GLM_YML_SERVICE_FILE \
  -c linux \
  -f SLES \
  -v $SLES_VER-$YYYYMMDD-BYOI \
  -u $IMAGE_URL_PREFIX/$GLM_CUSTOM_SLES_ISO
  -d $SLES_ISO_FILENAME \
  -i $GLM_CUSTOM_SLES_ISO \
  -t glm-autoinst.xml.template \
  -t glm-cloud-init.template"
echo $GEN_SERVICE
$GEN_SERVICE

# print out instructions for using this image & service
cat << EOF
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new GreenLake Metal (GLM) SLES service/image
| | that consists of the following 2 new files:
| |     $GLM_CUSTOM_SLES_ISO
| |     $GLM_YML_SERVICE_FILE
| |
| | To use this new GLM SLES service/image in HPE GLM take the following steps:
| | (1) Copy the new .ISO file ($GLM_CUSTOM_SLES_ISO)
| |     to your web server ($IMAGE_URL_PREFIX)
| |     such that the file can be downloaded from the following URL:
| |     $IMAGE_URL_PREFIX/$GLM_CUSTOM_SLES_ISO
| | (2) Add the GreenLake Metal Service file to your GLM Portal using this command:
| |     qctl services create -f $GLM_YML_SERVICE_FILE
| | (3) Create a host in GLM using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
EOF

exit 0
