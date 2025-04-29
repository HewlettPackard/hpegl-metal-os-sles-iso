#!/bin/bash
# (C) Copyright 2018-2022,2024 Hewlett Packard Enterprise Development LP

# This is the top level build script that will take a SLES install ISO and
# generate a SLES service.yml file that can be imported as a Host imaging
# service into a GreenLake Metal portal.

# glm-build-image-and-service.sh does the following steps:
# * process command line arguments.
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
# -r <rootpw>                | set the SLES OS root password
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
# -x <skip-test>             | [optional] Skip the test with "-x true"
#                            | By default this script will run the test "glm-test-service-image.sh"
#                            | script to verify that the upload was correct, and the size and checksum
#                            | of the ISO matches what is defined in the YML.
# -------------------------- | -----------

# NOTE: Make sure to upload the <glm-custom-sles-iso> .ISO file to your web server to make it accessible
# at this constructed URL: # <image-url-prefix>/<glm-custom-sles-iso>

# If the image URL cannot be constructed with this simple mechanism, then you probably need to customize
# this script for a more complex URL costruction.

# This script calls glm-image-build.sh, which needs the following packages to be installed:
# on Debian/Ubuntu:
# Command: `sudo apt install xorriso isomd5sum figlet cowsay`

# To run the test script: glm-test-service-image.sh
#   By default this script will run the test script "glm-test-service-image.sh"
#   to verify that the upload was correct, and the size and checksum of the
#   ISO matches what is defined in the YML.
#   Example:
#     ./glm-build-image-and-service.sh            \
#     -i images/SLE-15-SP4-Full-x86_64-Media1.iso \
#     -v SLE-15-SP6                               \
#     -r PASSWORD                                 \
#     -p https://10.152.3.96                      \
#     -o images/SLE-15-SP4-Full-x86_64-GLM.iso    \
#     -s images/SLE-15-SP4-Full-x86_64-GLM.yml

set -euo pipefail

# ==================================================================================
# Prerequisites:
# ==================================================================================
# Required parameters for Image Web Server and test script "glm-test-service-image.sh"
#   WEB_SERVER_IP: IP address of web server to transfer ISO to (via SSH)
#   REMOTE_PATH:   Path on web server to copy files to
#   SSH_USER:      Username for SSH transfer
#   Note: Add your Linux test machine's SSH key to the Web Server
WEB_SERVER_IP="10.152.3.96"
REMOTE_PATH="/var/www/images/"
SSH_USER_NAME="root"
# ==================================================================================

# other required parameters
SLES_ISO_FILENAME=""
GLM_CUSTOM_SLES_ISO=""
SLES_VER=""
DISTRO_ROOTPW=""
IMAGE_URL_PREFIX=""
GLM_YML_SERVICE_FILE=""
GLM_YML_SERVICE_TEMPLATE=""
SKIP_TEST=""

while getopts "i:v:r:o:p:s:x:" opt
do
    case $opt in
        # required parameters
        i) SLES_ISO_FILENAME=$OPTARG ;;
        v) SLES_VER=$OPTARG ;;
        r) DISTRO_ROOTPW=`openssl passwd -6 -salt xyz $OPTARG` ;;
        o) GLM_CUSTOM_SLES_ISO=$OPTARG ;;
        p) IMAGE_URL_PREFIX=$OPTARG ;;
        s) GLM_YML_SERVICE_FILE=$OPTARG ;;
        x) SKIP_TEST=$OPTARG ;;
        *) echo "ERROR invalid parameter."; exit 1 ;;
     esac
done

# Check that required parameters exist.
if [ -z "$SLES_ISO_FILENAME" -o \
     -z "$GLM_CUSTOM_SLES_ISO" -o \
     -z "$SLES_VER" -o \
     -z "$DISTRO_ROOTPW" -o \
     -z "$IMAGE_URL_PREFIX" -o \
     -z "$GLM_YML_SERVICE_FILE" ]; then
  echo "script usage: $0 -i sles-iso -v sles-version -r distro-rootpw" >&2
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
   if [ ! -z "$GLM_YML_SERVICE_TEMPLATE" ]; then
      rm -f $GLM_YML_SERVICE_TEMPLATE
   fi
}

# By default this script will run the test "glm-test-service-image.sh" script
# to verify that the upload was correct, and the size and checksum of the
# ISO matches what is defined in the YML.
# Note: Set the Web Server related parameters at the top
#   User may verify SCP transfer using following commands:
#     $ echo bye | sftp -b - ${SSH_USER_NAME}@${WEB_SERVER_IP}
#     $ rsync -av --dry-run ${SOURCE} ${DESTINATION}
run_test() {
if [ "${SKIP_TEST}" != "true" ]; then
  # Run the test by default
   echo -e "\nCopying .ISO file to the web server..."
   SOURCE="${GLM_CUSTOM_SLES_ISO}"
   DESTINATION="${SSH_USER_NAME}@${WEB_SERVER_IP}:${REMOTE_PATH}"
   echo "scp ${SOURCE} ${DESTINATION}"
   scp ${SOURCE} ${DESTINATION}
   if [ $? -ne 0 ]; then echo "ERROR scp failed to copy image"; exit 1; fi
   echo -e "\nRunning the test "glm-test-service-image.sh"..."
   echo "./glm-test-service-image.sh ${GLM_YML_SERVICE_FILE}"
   ./glm-test-service-image.sh ${GLM_YML_SERVICE_FILE}
fi
}

# Set a trap to call the clean function on exit
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

GLM_YML_SERVICE_TEMPLATE=$(mktemp /tmp/glm-service.cfg.XXXXXXXXX)
sed -e "s/SLES_VERSION/$SLES_VER/g" glm-service.yml.template > $GLM_YML_SERVICE_TEMPLATE

# set the root password in the KS configuration file (here, glm-autoinst.xml.template)
sed -i "s'%ROOTPW%'$DISTRO_ROOTPW'g" glm-autoinst.xml.template

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

# unset the root password in the KS configuration file (here, glm-autoinst.xml.template)
sed -i '/      <user_password>/c\      <user_password>%ROOTPW%</user_password>' glm-autoinst.xml.template

# By default run the test script "glm-test-service-image.sh" to verify ISO image
run_test

# print out instructions for using this image & service
NOTE="| |     
| |     IMPORTANT: Use the test (glm-test-service-image.sh) script to verify that
| |                the ISO upload was correct, and the size and checksum of the ISO
| |                match what is defined in the YML.
| |"

cat << EOF
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal $SLES_VER service/image
| | that consists of the following 2 new files:
| |     $GLM_CUSTOM_SLES_ISO
| |     $GLM_YML_SERVICE_FILE
| |
| | To use this new Bare Metal $SLES_VER service/image in Bare Metal, take the following steps:
| | (1) Copy the new .ISO file ($GLM_CUSTOM_SLES_ISO)
| |     to your web server ($IMAGE_URL_PREFIX) such that the file can be downloaded
| |     from the following URL: $IMAGE_URL_PREFIX/$GLM_CUSTOM_SLES_ISO
`if [ "${SKIP_TEST}" == "true" ]; then echo "${NOTE}"; echo ; else echo "| |"; fi`
| | (2) Add the Bare Metal Service file ($GLM_YML_SERVICE_FILE) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Metal Service file,
| |     sign in to the Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| |
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
EOF

exit 0
