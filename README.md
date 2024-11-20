<!-- (C) Copyright 2022,2024 Hewlett Packard Enterprise Development LP -->

# SLES Bring Your Own Image (BYOI) for GreenLake Metal (GLM)
# Table of contents
* [Building the SLES image](#building-the-sles-image)
* [Customizing the SLES image](#customizing-the-sles-image)
* [Using the SLES service/image](#using-the-sles-serviceimage)

# Overview

This github repository contains the script/template files and
documentation for creating a SLES service for HPE GreenLake Metal
(GLM) from a SLES install .ISO file.

**Prerequisites:**
```
1. You will need a Web Server with HTTPS support for storage of the HPE Base Metal images.
2. The Web Server is anything that:
    A. you have the ability to upload large OS image (.iso) to, and
    B. is on a network that will be reachable from the HPE On-Premises Controller.
       When an OS image service (.yml) is used to create an HPE Bare Metal Host, the HPE Bare Metal
       OS image (.iso) will be downloaded via the `secure_url` mentioned in the service file (.yml).
3. IMPORTANT:
   The test `glm-test-service-image.sh` script is to verify the HPE Bare Metal OS image (.iso).
   To run this test, edit the file `./glm-build-image-and-service.sh` to set the required
   Web Server-related parameters, listed below:
      +----------------------------------------------------------------------------
      | +--------------------------------------------------------------------------
      | | File `./glm-build-image-and-service.sh`
      | |   <1> WEB_SERVER_IP: IP address of web server to transfer ISO to (via SSH)
      | |       Example: WEB_SERVER_IP="10.152.3.96"
      | |   <2> REMOTE_PATH:   Path on web server to copy files to
      | |       Example: REMOTE_PATH="/var/www/images/"
      | |   <3> SSH_USER:      Username for SSH transfer
      | |       Example: SSH_USER_NAME="root"
      | | Note: Add your Linux test machine's SSH key to the Web Server
      | +--------------------------------------------------------------------------
      +----------------------------------------------------------------------------
   In this document, for the manual build example:
   A. a local Web Server "https://10.152.3.96" is used for the storage of OS images (.iso).
   B. we are assuming that the HPE Bare Metal OS images will be kept in: https://10.152.3.96/images/<.iso>
4. Linux machine for building OS image:
   A. Image building has been successfully tested with the following list of Ubuntu OS and its LTS versions:
      Ubuntu 20.04.6 LTS (focal)
      Ubuntu 22.04.5 LTS (jammy)
      Ubuntu 24.04.1 LTS (noble)
   B. Install supporting tools (git, xorriso, isomd5sum, figlet, and cowsay)
```

# Building the SLES image

These are the high-level steps required to generate the SLES service:
* Set up a Linux system with 20-40GB of free file system space for the build
* Set up a local file transfer/storage tool (E.g. **Local Web Server with HTTPS support**) that Bare Metal can reach over the network.
  * For **unsecured Web Server access**, please refer to the [Hosting](Hosting.md) for additional requirements, listed below:
    *  A. **HTTPS** with certificates signed by **publicly trusted Certificate authority**, and
    *  B. **Skip** the host’s **SSL certificate verification**.
  * For **Web Server running behind the Firewall**, the Web Server IP address and Port has to be whitelisted in the **rules** and **Proxy**.
* Install Git Version Control (git) and other supporting tools (xorriso, isomd5sum, figlet, and cowsay)
* Downloading recipe repo from GitHub
* Download a SLES .ISO file
* Build the Bare Metal SLES image/service

These are the high-level steps required to use this built GLM SLES
service/image on GLM:
* Copy the built GLM SLES .ISO image to your web server
* Add the GLM SLES .YML service file to the appropriate GLM portal
* In GLM create a host using this OS image service.

## Setup Linux system

These instructions and scripts are designed to run on a Linux system.
These instructions were developed and tested on a Ubuntu 20.04 VM, but
they should work on other distros/versions. The Linux host will need
to have the following packages installed for these scripts to run
correctly:

* xorriso
* isomd5sum
* syslinux-utils

On Ubuntu the necessary packages can be installed with:

```
sudo apt install xorriso isomd5sum syslinux-utils
```

The Linux host must have enough free file system space that images can
be easily generated (20-40GB).

The resulting SLES .ISO image file from the build needs to be uploaded
to a web server that the GLM Data Center Controller (DCC) can access
over the network.  More about this later.

## Downloading recipe repo from github

Once you have an appropriate Linux environment setup, then download
this recipe from github for building HPE GLM SLES by:

```
git clone https://github.com/hpe-hcss/bmaas-byoi-sles-image.git
```

## Downloading a SLES .ISO file

Next you will need to manually download the appropriate SLES .ISO onto
the Linux system.  If you don't already have a source for the SLES
.ISO files, then you might want to sign for a FREE SUSE
account at https://www.suse.com/download/sles/.

This SLES tested is working for SLES 15 SP3 and SP4. Note, the "Full" version of
the ISO is required. The "Online" version will not.

## Building the GLM SLES image/service

At this point, you should have a Linux system with:
* a copy of this repo
* a standard SLES Full .ISO file

We are almost ready to do the build, but we need to know something
about your environment.  When the build is done, it will generate two
files:
* a GLM-modified SLES .ISO file that needs to be hosted on a web
  server.  It is assumed that you have (or can setup) a local web
  server that GLM can reach over the network.  You will also need
  login credentials on this web server so that you can upload files.
* a GLM service .YML file that will be used to add the SLES service to
  the GLM portal.  This .YML file will have a URL to the GLM-modified SLES
  .ISO file on the web server.

The build needs to know what URL can be used to download the
GLM-modified SLES .ISO file. We assume that the URL can be broken into
2 parts: \<image-url-prefix\>/\<glm-custom-sles-iso\>

If the image URL cannot be constructed with this simple mechanism
then you probably need to customize this script for a more complex URL
costruction.

So you can run the build with the following command line parameters:

```
./glm-build-image-and-service.sh \
    -i <sles-iso-filename> \
    -v <sles-version-number> \
    -p <image-url-prefix> \
    -o <glm-custom-sles-iso> \
    -s <glm-yml-service-file>
```

Example: Run the build including artifact verification

```
./glm-build-image-and-service.sh \
   -i SLE-15-SP3-Full-x86_64-GM-Media1.iso \
   -v 15SP3 \
   -r qPassw0rd \
   -p https://10.152.3.96 \
   -o glm-metal-sles.iso
   -s glm-metal-sles-service.yml
```
Example: Run the build excluding artifact verification

```
./glm-build-image-and-service.sh \
   -i SLE-15-SP3-Full-x86_64-GM-Media1.iso \
   -v 15SP3 \
   -r qPassw0rd \
   -p https://10.152.3.96 \
   -o glm-metal-sles.iso
   -s glm-metal-sles-service.yml
   -x true
```

At the end of script run, it will output the following instructions for next steps:
```
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal SLES service/image
| | that consists of the following 2 new files:
| |     images/SLE-15-SP4-Full-x86_64-GM-GLM.iso
| |     images/SLE-15-SP4-Full-x86_64-GM-GLM.yml
| |
| | To use this new Bare Metal SLES service/image in Bare Metal, take the following steps:
| | (1) Copy the new .ISO file (images/SLE-15-SP4-Full-x86_64-GM-GLM.iso)
| |     to your web server (https://10.152.3.96) such that the file can be downloaded
| |     from the following URL: https://10.152.3.96/images/SLE-15-SP4-Full-x86_64-GM-GLM.iso
| | (2) Add the Bare Metal Service file (images/SLE-15-SP4-Full-x86_64-GM-GLM.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Metal Service file,
| |     sign in to the Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
```

When a SLES host is created in the GLM portal, the GLM DCC will pull
down this GLM-modified SLES .ISO file. This may take a little bit of time
the first time that DCC downloads the ISO from the web server.

### glm-build-image-and-service.sh - top level build script

This is the top level build script that will take a SLES install ISO and
generate a SLES service.yml file that can be imported as a Host
imaging Service into a GreenLake Metal portal.

glm-build-image-and-service.sh does the following steps:
* process command line arguements.
* Customize the SLES .ISO so that it works for GLM.  Run: glm-image-build.sh.
* Generate GLM service file for this GLM image that we just generated. Run: glm-service-build.sh.

glm-build-image-and-service.sh usage:

```
glm-build-image-and-service.sh -i <sles-iso-filename> -o <glm-custom-sles-iso>
    -v <sles-version-number> -p <image-url-prefix> -s <glm-yml-service-file>
```

glm-build-image-and-service.sh command line options | Description
----------------------------------------------------| -----------
-i \<sles-iso-filename\>     | local filename of the Full SLES .ISO file that was already downloaded. Used as input file.
-v \<sles-version-number\>   | a xy SLES version number.  Example: -v 15SP3
-o \<glm-custom-sles-iso\>   | local filename of the GLM-modified SLES .ISO file that will be output by the script.  This file should be uploaded to your web server.
-p \<image-url-prefix\>      | the beginning of the image URL (on your web server). Example: -p https://10.152.3.96.  The GLM service .YML will assume that the image file will be available at a URL constructed with \<image-url-prefix\>/\<glm-custom-sles-iso\>.
-s \<glm-yml-service-file\>  | local filename of the GLM .YML service file that will be output by the script.  This file should be uploaded to the GLM portal.

NOTE: The users of this script are expected to copy the
\<glm-custom-sles-iso\> .ISO file to your web server such that the file
is available at this constructed URL:
\<image-url-prefix\>/\<glm-custom-sles-iso\>

### glm-image-build.sh - Customize SLES.ISO for GLM

This script will repack a SLES .ISO file for a GLM SLES install service
that uses Virtual Media to get the install started.

The following changes are being made to the SLES .ISO:
  1. configure to use an autoinst.xml file on the iLO vmedia
     floppy and to pull the RPM packages (stage2) over vmedia
  2. setup for a text based install (versus a GUI install)
  3. set up the console to the iLO serial port (/dev/ttyS1)

The SLES .ISO is configured to use a autoinst.xml file on the iLO
vmedia floppy by adding the 'autoyast=usb:///glm-autoinst.xml' option in
GRUB (used in UEFI) and isolinux (used in BIOS) configuration
files. This option configures SLES installer to pull the
autoinst.xml file from the root of the floppy at /glm-autoinst.xml.  This
autoinst.xml option is setup by modifying the following files
on the .ISO:
  boot/x86_64/loader/isolinux.cfg for BIOS
  EFI/BOOT/grub.cfg for UEFI

Usage:
```
glm-build-image-and-service.sh -i <sles.iso> -v <version> -o <glm-customizied-sles.iso>
```

command line options          | Description
----------------------------- | -----------
-i \<sles.iso\>                 | Input SLES .ISO filename
-v \<version\>                  | SLES version number xy
-o \<glm-customizied-sles.iso\> | Output GLM SLES .ISO file

Here are the detailed changes that are made to the SLES .ISO:
* change the default timeout to 5 seconds (instead of 60 seconds)
* change the default menu selection to the 1st entry (no media check)
* add the 'autoyast=...' option to the various lines in the file
* also setup the serial console to ttyS1 (iLO serial port) with 115200 baud
* remove the 'splash=silent' option so the user can watch kernel loading
  and use to triage any problems

### glm-service-build.sh - Generate GLM .YML service file

This script generates a GreenLake Metal OS service.yml file
appropriate for uploading to a GLM portal(s).

Usage:
```
glm-service-build.sh -s <service-template> -o <service_yml_filename>
      -c <svc_category> -f <scv_flavor> -v <svc_ver>
      -d <display_url> -u <secure_url>
      -i <local_image_filename> [ -t <os-template> ]
```

command line options      | Description
------------------------- | -----------
-s \<service-template\>     | service template filename (input file)
-o \<service_yml_filename\> | service filename (output file)
-c \<svc_category\>         | GreenLake Metal service category
-f \<scv_flavor\>           | GreenLake Metal service flavor
-v \<svc_ver\>              | GreenLake Metal service version
-d \<display_url\>          | used to display the image URL in user interface
-u \<secure_url\>           | the real URL to the image file
-i \<local_image_filename\> | a full path to the image for this service. Used to get the .ISO sha256sum and size.
[ -t \<os-template\> ]      | info template files. 1st -t option should be %CONTENT1% in service-template. 2nd -> %CONTENT2%.

# Customizing the SLES image
autoinst
The SLES image/service can be customized by:
* Modifying the way the image is built
* Modifying the SLES autoinst file
* Modifying the cloud-init

## Modifying the way the image is built
Here is a description of the files in this repo:

Filename     | Description
-------------| -----------
README.md | This documentation
glm-build-image-and-service.sh | This is the top level build script that will take a SLES install ISO and generate a SLES service.yml file that can be imported as a Host imaging Service into a GreenLake Metal portal.
glm-image-build.sh | This script will repack SLES .ISO file for a GLM SLES install service that uses Virtual Media to get the install started.
glm-service-build.sh | This script generates a GreenLake Metal OS service.yml file appropriate for uploading the service to a GLM portal(s).
glm-service-cloud-init.template | This is the cloud-init template file that GLM will use to setup cloud-init to run on the 1st boot.
glm-service-ks-hostdef.cfg.template | A SLES autoinst file (templated with hostdef-v1) that is included into the core autoinst file.
glm-service-ks-install-env.cfg.template | The core SLES autoinst file (templated with install-env-v1)
glm-service-sles-service.yml.template | This is the GLM .YML service file template.
glm-test-service-image.sh | This script will verify that the OS image referred to in a corresponding Bare Metal OS service .yml is correct.
Hosting.md | This file is for additional requirements on the web server.

Feel free to modify these file to suite your specifc needs.  General
changes that you want to contribute back via a pull request are much
appreciated.

*The license for this repo has yet to be determined*.

## Modifying the SLES autoinst file

The SLES autoinst file is the basis of the automated install of SLES
supplied by this recipe.  Many additional changes to either of the
autoinst files are possible to customize to your needs.

## Customizing installed SLES packages (via autoinst)

The SLES install is driven by the primary autoinst file that is saved as glm-autoinst.xml.template in this repo.  In the middle of this file is a package list that looks like this:

```
<packages t="list">
  <package>...</package>
</packages>
```

Feel free to additional packages to list (as long as the packages are on the SLES .ISO).

Additional package can also be added when cloud-init runs if you
prefer that.

## Modifying the cloud-init

This service uses cloud-init to customize the deployed image after an autoinst-driven SLES install.
The cloud-init template is saved in this repo as glm-cloud-init.template.  Customizations of this file are possible.

# Using the SLES service/image

## Adding SLES service to GLM portal

When the build script completes successfully you will find the following
instructions there for how to add this image into your HPE GreenLake Metal
portal.  For example:

```
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal SLES service/image
| | that consists of the following 2 new files:
| |     images/SLE-15-SP4-Full-x86_64-GM-GLM.iso
| |     images/SLE-15-SP4-Full-x86_64-GM-GLM.yml
| |
| | To use this new Bare Metal SLES service/image in Bare Metal, take the following steps:
| | (1) Copy the new .ISO file (images/SLE-15-SP4-Full-x86_64-GM-GLM.iso)
| |     to your web server (https://10.152.3.96) such that the file can be downloaded
| |     from the following URL: https://10.152.3.96/images/SLE-15-SP4-Full-x86_64-GM-GLM.iso
| | (2) Add the Bare Metal Service file (images/SLE-15-SP4-Full-x86_64-GM-GLM.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Metal Service file,
| |     sign in to the Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
```

Follow the instructions as directed!

## Creating a SLES Host with SLES Service

### Triage of image deloyment problems

After you have created your custom SLES image/server and created a
host using this new service, you will want to monitor the deployment
for the first few times to make sure things are going as expected.
Here are some points to note:
  * This image/service is setup to output to the serial console during
    SLES deployment and watching the serial console is the easiest way
    to monitor the SLES deployment/installation.
  * HPE GreeLake Metal tools do not monitor the serial port(s) at this
    time so if an error is generated by the SLES installer, the GLM
    tools will not know about it.
  * Sometimes for more difficult OS deployment problems you might want
    to gain access to the servers iLO so that you can monitor it that
    way.  See your GLM administrator.

### Known problems/limitations with this image

* There are several arbitrary setting for the file system settings (file system type,
  size of partition, etc) that are embedded in the autoinst file in this SLES OS image
  (see glm-autoinst.xml.template).
* This SLES service will set a LVM volume using all available storage on the server.
  This is probably not the desired behavior for all situations but it does make the
  service more robust (works when there is not sda but other storage is present).
  This will change when we get more RAID setup support implemented.
* There is NO automated installation of ProLiant Support Packs or other HPE
  software that might be recommended for SLES on HPE servers.

### Login Credentials

This GLM SLES recipe (by default) when deployed will:
* Not create a non-root user login. Neither the GLM SLES autoinst nor
  cloud-init files will create any user beyond the root user,
* Not create a root password.  Neither the GLM SLES autoinst nor
  cloud-init files will setup any root password,
* The SSH Keys supplied in the GLM Host creation are added to the root
  user by the cloud-init file (see glm-cloud-init.template).

The implications of the default setup are:
* Because there is no user with a password setup, there is no way to
  login to the SLES host via the GLM serial console,
* The only way to login is via the root user via ssh and the GLM
  installed SSH Keys,
* If you want to create another non-root user account then you can add
  that to either the autoinst or cloud-init files as desired.

### SLES License

SLES is a licensed software and users need to have a valid license key
from SUSE to use SLES.  This install service does nothing to setup a
SLES license key in any way.  Users are expected to manually use SLES
tools to setup a SLES license on the host.

### Network Setup

Host network setup should happen automatically.  To validate the
network connectivity with curl for example:

```
[user@host ~]$ curl -k https://google.com
<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="https://www.google.com/">here</A>.
</BODY></HTML>
[user@host ~]$
```

The GreenLake Metal will setup the cloud-init files
`/etc/cloud/cloud.cfg.d/9?_datasource.cfg`.  If the network setup is
not right in these cloud-init files then it will never be right on the
deployed host.  To validate the deployment of the cloud-init files see
`/var/log/cloud-init-output.log`.

### iSCSI (Nimble/etc) Setup

When a host is setup with a iSCSI (Nimble/etc) volume then the Nimble
volume should be automatcally setup, for example:

```
[root@host ~]# lsscsi
[0:0:0:0]    cd/dvd  iLO      Virtual DVD-ROM        /dev/sr0
[1:0:0:0]    disk    ATA      MM1000GFJTE      HPG5  /dev/sda
[7:0:0:0]    disk    Nimble   Server           1.0   /dev/sdb
[root@host ~]#
```
