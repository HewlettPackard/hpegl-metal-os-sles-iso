#!/bin/bash
# (C) Copyright 2020-2022,2024 Hewlett Packard Enterprise Development LP

# This build-image.sh script will build a SLES BYOI image and put the
# results in AWS S3 storage.  This script runs automatically as a
# GitHub Actions Job.  Right now the BYOI files have been copied into
# this private repository (until the BYOI files are on a public repository
# i.e. https://github.com/HewlettPackard/hpegl-metal-os-sles-iso).

set -eux -o pipefail

# DEFAULT TEST RUN:
#=======================================================================================
# By default this script will run the test script "glm-test-service-image.sh" to verify:
# 1. the ISO image upload was correct,
# 2. the size amd the signature of ISO matches what is defined in the YML.
# NOTE: To skip this test, set SKIP_TEST="true"
SKIP_TEST="false"
#=======================================================================================

install_pkgs() {
  sudo apt-get update
  sudo apt-get install figlet cowsay xorriso isomd5sum
  # cowsay is now in /usr/games
  export PATH=$PATH:/usr/games/
}

# create a message
message() {
  if [ -f /usr/games/cowsay ] && [ -f /usr/bin/figlet ]; then
    figlet $@ | cowsay -f dragon-and-cow -n
  fi
}

# upload files to S3
function upload_file_to_storage {
    local staging_dir=$(mktemp -d)
    local container_mount_dir=/tmp/output/

    chmod -R 0755 ${staging_dir}

    if [[ -z ${1} ]]; then
        echo "missing local file path " && false
    fi
    local local_file=${1}
    local file_name=$(basename ${local_file})

    if [[ -z ${2} ]]; then
        echo "missing remote file path " && false
    fi
    local remote_path=${2}

    # copying to temp staging directory
    cp ${local_file} ${staging_dir}/

    # Run the upload_to_s3.sh script in the bmaas-imaging container to
    # upload the file to S3.
    ./bmaas-imaging/scripts/s3tools/upload_to_s3.sh -s "${container_mount_dir}/${file_name}" -d "${remote_path}"

    # deleting the temp staging directory
    sudo rm -rf ${staging_dir}
}

# generate a signed URL
function gen_signed_url() {
    remote_path=${1}

    # Run the gen_signed_url.sh script in the bmaas-imaging container to
    # generate a signed URL ( and ultimately the secure_url value in the service.yml file).
    ./bmaas-imaging/scripts/s3tools/gen_signed_url.sh -p ${remote_path}
}

# By default this script will run the test "glm-test-service-image.sh" script
# to verify that the upload was correct, and the size and checksum of the
# ISO matches what is defined in the YML.
run_test() {
  # Skip the test with setting SKIP_TEST="true" at the top
  if [[ "${SKIP_TEST}" != "true" ]]; then
    message Run Test
    echo "./glm-test-service-image.sh ${GLM_SVC_YML}"
    ./glm-test-service-image.sh ${GLM_SVC_YML}
  fi
}

# This is the SLES .ISO file that has been uploaded to S3 as an asset
# for use in build the SLES service
pull_iso() {
  # generate a signed URL to the SLES file
  echo "Generating signed URL for ${S3_SLES_ISO}..."
  SLES_ISO_URL=$(gen_signed_url "${S3_SLES_ISO}")
  if [[ $? -ne 0 ]]; then
      echo "Failed to generate Signed URL: ${S3_SLES_ISO}"
  fi

  # download the SLES .ISO file using the signed URL that we generated
  wget -O ${SLES_ISO} ${SLES_ISO_URL} --no-verbose
}

# building SLES BYOI image
run_byoi_build() {
  message Building SLES BYOI Image...

  echo
  echo "Processing $SLES_ISO (SLES Version $SLES_VER) into $GLM_SLES_ISO and $GLM_SVC_YML."
  echo

# Parameter "-x true" added to avoid the duplicate test run (only during the CI/CD build)
  BUILD="./glm-build-image-and-service.sh \
    -i $SLES_ISO \
    -v $SLES_VER \
    -r qPassw0rd \
    -p dummy-url-prefix \
    -o $GLM_SLES_ISO \
    -s $GLM_SVC_YML \
    -x true"
  echo $BUILD
  $BUILD >> log
}

# upload the GLM Image (.iso) and GLM Service (.yml) to S3
upload_image_and_service() {
  message Uploading GreenLake Metal image/service to S3:...

  # We need these values from glm-build-image-and-service.sh
  SVC_CATEGORY="linux"
  SVC_FLAVOR="SLES"
  SVC_VER="$SLES_VER-$YYYYMMDD-BYOI"

  # Upload the image to S3 Storage.
  file_name=$(basename ${GLM_SLES_ISO})
  S3_IMAGE_FILEPATH="images/${SVC_CATEGORY}/${SVC_FLAVOR}/${SVC_VER}/${file_name}"

  echo "Copying Image ${GLM_SLES_ISO} to S3 bucket path ${S3_IMAGE_FILEPATH}..."
  DISPLAY_URL=$(upload_file_to_storage "${GLM_SLES_ISO}" "${S3_IMAGE_FILEPATH}")
  if [[ $? -ne 0 ]]; then
    echo "Failed to copy image: ${DISPLAY_URL}"
  fi

  echo "Generating signed URL for ${S3_IMAGE_FILEPATH}..."
  SECURE_URL=$(gen_signed_url "${S3_IMAGE_FILEPATH}")
  if [[ $? -ne 0 ]]; then
    echo "Failed to generate Signed URL: ${SECURE_URL}"
  fi

  # Sed treats '&' specially, so replacing '&' with '\&' in the URLs
  SECURE_URL=`echo $SECURE_URL | sed "s/\&/\\\\\&/g"`
  DISPLAY_URL=`echo $DISPLAY_URL | sed "s/\&/\\\\\&/g"`

  # Now that we have the DISPLAY_URL and SECURE_URL for the GLM_SLES_IMAGE
  # adjust the service file display_url and secure_url fields
  sed -i -e "s#display_url: .*\$#display_url: \"${DISPLAY_URL}\"#" \
    -e "s#secure_url: .*\$#secure_url: \"${SECURE_URL}\"#" $GLM_SVC_YML

  # Upload the *service.yml to S3 Storage.
  LOCAL_SERVICE_FILE=$(basename ${GLM_SVC_YML})
  S3_SERVICE_FILEPATH="services/${SVC_CATEGORY}/${SVC_FLAVOR}/${SVC_VER}/${LOCAL_SERVICE_FILE}"

  echo
  echo "Copying Service file ${GLM_SVC_YML} to ${S3_SERVICE_FILEPATH}..."
  S3_SERVICE_PATH=$(upload_file_to_storage "${GLM_SVC_YML}" "${S3_SERVICE_FILEPATH}")
  if [[ $? -ne 0 ]]; then
    echo "Failed to copy service yaml: ${out}"
  fi

  echo "Generating signed URL for ${S3_SERVICE_FILEPATH}..."
  SERVICE_URL=$(gen_signed_url "${S3_SERVICE_FILEPATH}")
  if [[ $? -ne 0 ]]; then
    echo "Failed to generate Signed URL: ${SERVICE_URL}"
  fi

  # By default run the test script "glm-test-service-image.sh" to verify ISO image
  run_test

  # generate instructions for using this image/service.
  cat << EOF >> /tmp/${OS_VERSION}-Service-Install.log

+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | The Generated Image has been uploaded to the HPE Bare Metal S3 Image storage
| | at ${DISPLAY_URL}
| |
| | The Generated Service File has been uploaded to the HPE Bare Metal S3 Image storage
| | at ${SERVICE_URL}
| |
| | To use this Image, take the following steps:
| | (1) Pull down the HPE Bare Metal Service file from ${SERVICE_URL} for example
| |     wget -O ${LOCAL_SERVICE_FILE} "${SERVICE_URL}"
| | (2) Add the HPE Bare Metal Service file ${LOCAL_SERVICE_FILE} to the HPE Bare Metal Portal:
| |     (2A) To add the HPE Bare Metal Service file to the HPE Bare Metal Portal
| |          (https://client.greenlake.hpe.com/), sign in to the HPE Bare Metal Portal and
| |          select the Tenant by clicking "Go to tenant". Select the Dashboard tile "Metal Consumption"
| |          and click on the Tab "OS/application images". Click on the button "Add OS/application image"
| |          to Upload the OS/application YAML file.
| |     (2B) To add the HPE Metal Service file to your local Bare Metal Portal using "qctl" command:
| |          qctl services create -f ${LOCAL_SERVICE_FILE}
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------

EOF
}

if [ "$#" -ne 1 ] ; then
  echo "Script Usage: $0 <sle-os-name>"
  echo "     Example: $0 SLE-15-SP3"
  exit 1
fi

OS_VERSION=$1
case $OS_VERSION in
  "SLE-15-SP3") S3_SLES_ISO="assets/linux/SLES/SLE-15-SP3-Full-x86_64-GM-Media1.iso"  ;;
  "SLE-15-SP4") S3_SLES_ISO="assets/linux/SLES/SLE-15-SP4-Full-x86_64-GM-Media1.iso"  ;;
  *) echo "ERROR Invalid OS name."; exit 1 ;;
esac

YYYYMMDD=$(date '+%Y%m%d')
ID=$RANDOM

install_pkgs
mkdir /tmp/output

echo Processing $(basename $S3_SLES_ISO)
SLES_ISO=$(basename $S3_SLES_ISO | sed -e "s/^/\/tmp\/output\//")
GLM_SLES_ISO=$(echo $SLES_ISO | sed -e "s/\.iso/-hpe-glm-${YYYYMMDD}-${ID}.iso/g")
GLM_SVC_YML=$(echo $SLES_ISO | sed -e "s/\.iso/-service-${YYYYMMDD}-${ID}.yml/g")
SLES_VER=$(echo $SLES_ISO | sed -e "s/.*SLE-\([0-9.]*\)-SP\([0-9]*\).*/\1-SP\2/")

pull_iso
run_byoi_build
upload_image_and_service

# copy the service .yml file for uploading to artifacts
cp $GLM_SVC_YML /tmp/
echo $SERVICE_URL > /tmp/glm_svc_yml.txt

echo Remove previous image build files
rm $SLES_ISO $GLM_SLES_ISO $GLM_SVC_YML

# output the accumulated instructions
cat /tmp/${OS_VERSION}-Service-Install.log
message Success
