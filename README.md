<!-- (C) Copyright 2022,2024-2025 Hewlett Packard Enterprise Development LP -->

# SLES Bring Your Own Image (BYOI) for GreenLake Metal (GLM)
# Table of contents
* [Building the SLES image](#building-the-sles-image)
* [Customizing the SLES image](#customizing-the-sles-image)
* [Using the SLES service/image](#using-the-sles-serviceimage)

# Overview

This GitHub repository includes scripts, template files, and documentation for creating a SLES service for HPE GreenLake Metal (GLM) using a SLES installation .ISO file.

# Supported HPE PCE Bare Metal Operating Systems

Service Category | Service Flavor    | Service Version 
---------------- | ----------------- | --------------------------------------------
Linux            | SLES              | SLES 15 SP3, SLES 15 SP4


# Supported Network Bonding Configuration for HPE PCE Bare Metal
This section provides the BMaaS OS configurations for SLES, outlining Switch LAG (Link Aggregation Group) settings along with bonding modes and key configuration parameters.<BR><BR>
**Additional Reference:** For a detailed overview of bonding modes and the required switch settings, please refer to the official [SLES 15 SP4 Networking info]([https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_networking/configuring-network-bonding_configuring-and-managing-networking#configuring-network-bonding_configuring-and-managing-networking](https://documentation.suse.com/sles/15-SP4/html/SLES-all/cha-network.html)).

Switch LAG   | Configuration Details |
------------ | --------------------- |
**Disabled** <BR> (Default Configuration) | **Configuration Details:** This is the **$${\color{red}default}$$** bonding  mode for the host. <BR><BR> **Behavior:** When the switch LAG is disabled, the bond mode is set to TLB (Transmit Load Balancing). In this mode, only one network port will receive incoming traffic, while all network ports in the bond will participate in transmitting outgoing traffic. |
**Enabled** <BR> (User Configurable)  | **Configuration Details:** When the switch LAG is enabled, the bonding mode **needs to be set manually to Balance XOR**. <BR><BR> **Behavior:** When the switch LAG is enabled and the bond mode is set to XOR, the switch is configured to allow receiving traffic on both network ports. <BR><BR> **Configuration Steps:** <BR> <1> Set `no_switch_lag` to `false` in the **OS Image Service file** ([glm-service.yml.template](glm-service.yml.template)) <BR> <2> In the cloud-init configuration file ([glm-cloud-init.template](glm-cloud-init.template)), update the bonding mode by setting: <BR> `bond-mode: balance-xor`. |


**Prerequisites:**
```
1. You will need a Web Server with HTTPS support for storage of the HPE Bare Metal images.
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

These are the high-level steps required to use this built GLM SLES service/image on GLM:
* Copy the built GLM SLES .ISO image to your web server
* Add the GLM SLES .YML service file to the appropriate GLM portal
* In GLM create a host using this OS image service.

## Setup Linux system

These instructions and accompanying scripts are designed to run on a Linux system. They have been developed and tested on an Ubuntu 20.04 virtual machine but should work on other Linux distributions and versions as well.

To ensure proper execution, the Linux host must have the following packages installed:
* xorriso
* isomd5sum
* syslinux-utils

On Ubuntu (the build system), you can install these packages by running:
```
sudo apt install xorriso isomd5sum syslinux-utils
```

Additionally, please ensure that your Linux host has sufficient free disk space - typically between 20 and 40 GB - to comfortably generate the image files.

Once the build completes, the resulting SLES .ISO image must be uploaded to a web server accessible by the GreenLake Metal Data Center Controller (DCC) over the network. Further details on this process will be provided later.

## Downloading recipe repo from github

Once you have your Linux environment properly set up, download this HPE GLM SLES build recipe from GitHub by running:
```
git clone https://github.com/HewlettPackard/hpegl-metal-os-sles-iso.git
```
Change directory to the cloned folder:
```
cd hpegl-metal-os-sles-iso
mkdir images
```

## Downloading a SLES .ISO file

Next, you will need to manually download the appropriate SLES .ISO file onto your Linux system. If you do not already have access to the SLES .ISO, you can sign up for a free SUSE account at https://www.suse.com/download/sles/.

This setup has been successfully tested with `SLES 15 SP3` and `SLES 15 SP4`.  
Note: Please ensure you use the "Full" ISO version of the SLES installation media. The "Online" ISO is not supported for this process.

For Example: ISO Image downloaded and copied at `images/SLE-15-SP4-Full-x86_64-GM-Media1.iso`

## Building the GLM SLES image/service

At this stage, you should have the following ready on your Linux system:
* a local copy of this repository
* a standard SLES Full .ISO file

We are nearly ready to proceed with the build, but first, we need some details about your environment. Upon completion, the build will generate two key files:
* GLM-modified SLES .ISO file: This customized ISO must be hosted on a web server accessible by the GLM portal. You should have, or be able to set up, a local web server reachable over your network, along with the necessary login credentials to upload files.
* GLM service .YML file: This YAML file is used to add the SLES service to the GLM portal and contains the URL pointing to the GLM-modified SLES .ISO hosted on your web server.

To successfully configure the build, you must specify the base URL from which the GLM-modified SLES .ISO will be served. We assume this URL follows the format: `<image-url-prefix>/<glm-custom-sles-iso>`

If your image URL cannot be constructed using this straightforward pattern, you may need to customize the script to handle a more complex URL structure.

So you can run the build with the following command line parameters:
```
./glm-build-image-and-service.sh \
    -i <sles-iso-filename> \
    -v <sles-version-number> \
    -r <root-password> \
    -p <image-url-prefix> \
    -o <glm-custom-sles-iso> \
    -s <glm-yml-service-file>
```

Example #1: Running the build with artifact verification

```
./glm-build-image-and-service.sh \
   -i images/SLE-15-SP4-Full-x86_64-GM-Media1.iso \
   -v SLE-15-SP4 \
   -r qPassw0rd \
   -p https://10.152.3.96 \
   -o images/SLE-15-SP4-Full-x86_64-GM-GLM.iso \
   -s images/SLE-15-SP4-Full-x86_64-GM-GLM.yml
```

At the end of the script execution, it will display instructions for the next steps, such as:
```
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal SLE-15-SP4 service/image
| | that consists of the following 2 new files:
| |     images/SLE-15-SP4-Full-x86_64-GM-GLM.iso
| |     images/SLE-15-SP4-Full-x86_64-GM-GLM.yml
| |
| | To use this new Bare Metal SLE-15-SP4 service/image in Bare Metal, take the following steps:
| | (1) Copy the new .ISO file (images/SLE-15-SP4-Full-x86_64-GM-GLM.iso)
| |     to your web server (https://10.152.3.96) such that the file can be downloaded
| |     from the following URL: https://10.152.3.96/images/SLE-15-SP4-Full-x86_64-GM-GLM.iso
| |
| | (2) Add the Bare Metal Service file (images/SLE-15-SP4-Full-x86_64-GM-GLM.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Metal Service file,
| |     sign in to the Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| |
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
```
Example #2: Running the build without artifact verification

```
./glm-build-image-and-service.sh \
   -i images/SLE-15-SP4-Full-x86_64-GM-Media1.iso \
   -v SLE-15-SP4 \
   -r qPassw0rd \
   -p https://10.152.3.96 \
   -o images/SLE-15-SP4-Full-x86_64-GM-GLM.iso \
   -s images/SLE-15-SP4-Full-x86_64-GM-GLM.yml
   -x true
```

At the end of the script execution, it will display instructions for the next steps, such as:
```
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal SLE-15-SP4 service/image
| | that consists of the following 2 new files:
| |     images/SLE-15-SP4-Full-x86_64-GM-GLM.iso
| |     images/SLE-15-SP4-Full-x86_64-GM-GLM.yml
| |
| | To use this new Bare Metal SLE-15-SP4 service/image in Bare Metal, take the following steps:
| | (1) Copy the new .ISO file (images/SLE-15-SP4-Full-x86_64-GM-GLM.iso)
| |     to your web server (https://10.152.3.96) such that the file can be downloaded
| |     from the following URL: https://10.152.3.96/images/SLE-15-SP4-Full-x86_64-GM-GLM.iso
| |
| |     IMPORTANT: Use the test (glm-test-service-image.sh) script to verify that
| |                the ISO upload was correct, and the size and checksum of the ISO
| |                match what is defined in the YML.
| |
| | (2) Add the Bare Metal Service file (images/SLE-15-SP4-Full-x86_64-GM-GLM.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Metal Service file,
| |     sign in to the Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| |
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
```

When a SLES host is created in the GreenLake Metal (GLM) portal, the GLM DCC will automatically download the GLM-customized SLES ISO.  
Note: The first download may take some time, as the ISO is pulled from the designated web server.

### glm-build-image-and-service.sh - top level build script

This is the primary build script used to generate a GLM-compatible service.yml from a standard SLES installation ISO. The resulting YAML file can then be imported into the GreenLake Metal portal as a Host Imaging Service.

glm-build-image-and-service.sh does the following steps:
* Parses and validates command-line arguments
* Customizes the SLES ISO for GLM using glm-image-build.sh
* Generates the service.yml for the customized image using glm-service-build.sh

glm-build-image-and-service.sh usage:

```
glm-build-image-and-service.sh -i <sles-iso-filename> -o <glm-custom-sles-iso>
    -v <sles-version-number> -p <image-url-prefix> -s <glm-yml-service-file>
```

| Option                      | Description                                                                                                                                                                                                                                              |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-i <sles-iso-filename>`    | Path to the **local** SLES Full ISO file that has already been downloaded. This will be used as the input ISO.                                                                                                                                           |
| `-v <sles-version-number>`  | The **SLES version number**, e.g., `15SP3`.                                                                                                                                                                                                              |
| `-r <sles-rootpw>`          | The **root user password** in plain text.                                                                                                                                                                                                                |
| `-o <glm-custom-sles-iso>`  | Output filename for the **GLM-customized SLES ISO**. This ISO should later be uploaded to your web server.                                                                                                                                               |
| `-p <image-url-prefix>`     | The **base URL** where the ISO will be hosted (e.g., `https://10.152.3.96`). The generated GLM service YAML will reference the image using: `<image-url-prefix>/<glm-custom-sles-iso>`.                                                                  |
| `-s <glm-yml-service-file>` | Output filename for the **GLM service YAML file**, which should be uploaded to the GLM portal.                                                                                                                                                           |
| `-x <skip-test>`            | *(Optional)* Set to `true` to **skip validation testing**. <br>**Note:** By default, the script will run [`glm-test-service-image.sh`](glm-test-service-image.sh) to verify the uploaded ISO (size and checksum must match the values in the YAML file). |

Note:  
Users of this script are expected to manually copy the generated <glm-custom-sles-iso> file to their web server, ensuring it is accessible at the following constructed URL:  \<image-url-prefix\>/\<glm-custom-sles-iso\>

### glm-image-build.sh - Customize SLES.ISO for GLM

This script repackages a standard SLES installation ISO to make it compatible with GreenLake Metal (GLM), enabling deployment via Virtual Media (vMedia).

Key Customizations Made to the ISO:
  1. Configures the installer to:
    * Use an autoinst.xml file from the iLO vMedia floppy.
    * Pull RPM packages (stage2) over vMedia.
  2. Sets up the installation as text-based, instead of GUI-based.
  3. Configures the console to use the iLO serial port (/dev/ttyS1).

To enable use of the autoinst.xml file from the vMedia floppy, the ISO is modified to include the following boot option:
`autoyast=usb:///glm-autoinst.xml`
This directive instructs the installer to load the AutoYaST configuration file from the root of the floppy device, located at /glm-autoinst.xml.

Bootloader Files Modified:
* boot/x86_64/loader/isolinux.cfg – for BIOS-based systems
* EFI/BOOT/grub.cfg – for UEFI-based systems
These changes ensure both boot modes are supported with the custom autoinstall settings.

Usage:
```
glm-build-image-and-service.sh
      -i <sles.iso>
      -v <version>
      -o <glm-customizied-sles.iso>
```

| Option                         | Description                                                          |
| ------------------------------ | -------------------------------------------------------------------- |
| `-i <sles.iso>`                | Path to the input **SLES installation ISO** file.                    |
| `-v <version>`                 | SLES version identifier (e.g., `15SP3`, `15SP4`).                    |
| `-o <glm-customized-sles.iso>` | Output filename for the **GLM-customized SLES ISO** to be generated. |


**Detailed Modifications Made to the SLES ISO**  
The following changes are applied to the original SLES ISO during customization:
* Reduced boot timeout from 60 seconds to 5 seconds for faster unattended startup.
* Set the default boot menu option to the first entry (skipping the media check).
* Appended the autoyast=... parameter to the boot configuration to enable automated installation via the vMedia floppy.
* Configured serial console output to use /dev/ttyS1 (iLO serial port) at 115200 baud, ensuring visibility during headless or remote installs.
* Removed the splash=silent parameter, allowing full kernel boot messages to display for better visibility and easier troubleshooting.


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

| Command Line Option          | Description                                                                                                                   |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| -s \<service-template>       | Input service template filename                                                                                               |
| -o \<service\_yml\_filename> | Output service YAML filename                                                                                                  |
| -c \<svc\_category>          | GreenLake Metal service category                                                                                              |
| -f \<svc\_flavor>            | GreenLake Metal service flavor                                                                                                |
| -v \<svc\_ver>               | GreenLake Metal service version                                                                                               |
| -d \<display\_url>           | URL displayed in the user interface to represent the image                                                                    |
| -u \<secure\_url>            | Actual URL where the image file is hosted                                                                                     |
| -i \<local\_image\_filename> | Full path to the local image file, used to calculate the .ISO SHA256 checksum and file size                                   |
| \[ -t \<os-template> ]       | Optional info template files; the first -t option replaces %CONTENT1% in the service template, the second replaces %CONTENT2% |


# Customizing the SLES image
autoinst
The SLES image/service can be customized by:
* Modifying the way the image is built
* Modifying the SLES autoinst file
* Modifying the cloud-init

## Modifying the way the image is built
Here is a description of the files in this repo:

| Filename                                  | Description                                                                                                                           |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `README.md`                               | Overview and usage documentation.                                                                                                     |
| `glm-build-image-and-service.sh`          | Top-level build script that takes a SLES install ISO and generates a GLM-compatible `service.yml` file for importing into the portal. |
| `glm-image-build.sh`                      | Repackages the SLES ISO for GreenLake Metal (GLM) deployment using Virtual Media (vMedia).                                            |
| `glm-service-build.sh`                    | Generates the `service.yml` file required for uploading the OS image as a service in the GLM portal.                                  |
| `glm-service-cloud-init.template`         | Cloud-init template used by GLM to configure the host on first boot.                                                                  |
| `glm-service-ks-hostdef.cfg.template`     | Templated SLES `autoinst` fragment for host-specific configuration (`hostdef-vX`).                                                    |
| `glm-service-ks-install-env.cfg.template` | Core `autoinst` template used during installation (`install-env-v1`).                                                                 |
| `glm-service-sles-service.yml.template`   | Template for the final GLM service YAML (`.yml`) file.                                                                                |
| `glm-test-service-image.sh`               | Verifies that the OS image referenced in a GLM `.yml` service file is present, correctly sized, and has the expected checksum.        |
| `Hosting.md`                              | Contains web server requirements for hosting ISO and service files.                                                                   |

**Feel free to modify these files to suit your specific needs.**  
Contributions of general improvements via pull requests are always welcome and appreciated.

*The license for this repo has yet to be determined*.

## Modifying the SLES autoinst file

The SLES autoinst file serves as the foundation for the automated SLES installation provided by this recipe. You can further customize the installation by making additional changes to either of the autoinst files to suit your specific requirements.

## Customizing installed SLES packages (via autoinst)

The SLES installation is controlled by the primary autoinst file, saved as glm-autoinst.xml.template in this repository. Within this file, you’ll find a package list section that appears as follows:

```
<packages t="list">
  <package>...</package>
</packages>
```

You are welcome to add additional packages to the list, provided they are included on the SLES .ISO.
Alternatively, you can also add packages during the cloud-init phase after installation, if preferred.

## Modifying the cloud-init

This service utilizes cloud-init to customize the deployed image following the autoinst-driven SLES installation.
The cloud-init template is available in this repository as glm-cloud-init.template, and can be customized to suit your requirements.

# Using the SLES service/image

## Adding SLES service to GLM portal

Upon successful completion of the build script, instructions will be provided on how to add this image to your HPE GreenLake Metal portal. For example:

```
+------------------------------------------------------------------------------------------
| +----------------------------------------------------------------------------------------
| | This build has generated a new HPE Bare Metal SLE-15-SP4 service/image
| | that consists of the following 2 new files:
| |     images/SLE-15-SP4-Full-x86_64-GM-GLM.iso
| |     images/SLE-15-SP4-Full-x86_64-GM-GLM.yml
| |
| | To use this new Bare Metal SLE-15-SP4 service/image in Bare Metal, take the following steps:
| | (1) Copy the new .ISO file (images/SLE-15-SP4-Full-x86_64-GM-GLM.iso)
| |     to your web server (https://10.152.3.96) such that the file can be downloaded
| |     from the following URL: https://10.152.3.96/images/SLE-15-SP4-Full-x86_64-GM-GLM.iso
| |
| |     IMPORTANT: Use the test (glm-test-service-image.sh) script to verify that
| |                the ISO upload was correct, and the size and checksum of the ISO
| |                match what is defined in the YML.
| |
| | (2) Add the Bare Metal Service file (images/SLE-15-SP4-Full-x86_64-GM-GLM.yml) to the HPE Bare Metal Portal
| |     (https://client.greenlake.hpe.com/). To add the HPE Metal Service file,
| |     sign in to the Bare Metal Portal and select the Tenant by clicking "Go to tenant".
| |     Select the Dashboard tile "Metal Consumption" and click on the Tab "OS/application images".
| |     Click on the button "Add OS/application image" to Upload the OS/application YML file.
| |
| | (3) Create a Bare Metal host using this OS image service.
| +----------------------------------------------------------------------------------------
+------------------------------------------------------------------------------------------
```
Follow the instructions as directed!


## Creating a SLES Host with SLES Service

### Triage of image deloyment problems

Once you’ve created your custom SLES image and deployed a host using this new service, it’s recommended to monitor the deployment process - at least for the first few runs - to ensure everything proceeds as expected.

**Key Points to Keep in Mind:**  
* This image/service is configured to output to the serial console during the SLES deployment. Monitoring the serial console is the most effective way to track installation progress.
* HPE GreenLake Metal (GLM) tools currently do not monitor serial port output. If the SLES installer encounters an error, it may go undetected by GLM unless you are watching the console directly.
* For troubleshooting or more complex deployment issues, direct iLO access to the server may be required. Please contact your GLM administrator to obtain iLO credentials or assistance.

### Known problems/limitations with this image

* The filesystem configuration (such as filesystem type, partition sizes, etc.) is predefined in the SLES OS image and embedded within the glm-autoinst.xml.template file. These settings can be customized if needed.
* By default, this SLES service uses LVM and will allocate all available storage on the server. While this provides robustness—especially in cases where the primary disk is not /dev/sda - it may not be ideal for all deployment scenarios.
  * Note: This behavior may change in future revisions once improved RAID support is implemented.
* There is no automated installation of ProLiant Support Packs (PSP) or other HPE-recommended software for SLES on ProLiant servers. If required, these components must be installed manually after deployment.

### Login Credentials

When deployed using this GLM SLES recipe, the following default behaviors apply:
* No non-root user is created: Neither the autoinst.xml nor the cloud-init file provisions a standard (non-root) user account.
* No root password is set: The deployment does not configure a root password. The root account is accessible only via SSH key authentication.
* SSH keys from GLM Host definition are applied: The SSH public keys specified during host creation in the GreenLake Metal portal are injected into the root account via the cloud-init configuration (glm-cloud-init.template).

**Implications of the Default Setup**
* Console login is not possible: Since no user account with a password is configured, login via the GLM serial console is not supported by default.
* SSH access only via key authentication: Access to the system is possible only through the root user using SSH and the pre-configured SSH keys from GLM.
* Optional user configuration: If additional user accounts (non-root) or a root password are needed, you can modify:
  * the `autoinst.xml` (for setup during installation), or
  * the `cloud-init` template (for post-install provisioning).

### SLES License

SLES is licensed software, and users must possess a valid license key from SUSE to use it legally.
This installation service does not include any mechanism to configure or apply a SLES license key.
Users are responsible for manually registering and activating their SLES license on the host using SUSE’s standard licensing tools.

### Network Setup

The host network setup is expected to be automatic. To verify network connectivity, you can use tools like curl. For example:
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

GreenLake Metal configures the cloud-init files located at `/etc/cloud/cloud.cfg.d/9?_datasource.cfg`. If the network configuration within these cloud-init files is incorrect, the deployed host will not have proper network setup. To verify that the cloud-init files were applied correctly during deployment, please check the log file at `/var/log/cloud-init-output.log`.

### iSCSI (Nimble/etc) Setup

When a host is configured with an iSCSI volume (e.g., Nimble), the Nimble volume should be automatically set up. For example:

```
[root@host ~]# lsscsi
[0:0:0:0]    cd/dvd  iLO      Virtual DVD-ROM        /dev/sr0
[1:0:0:0]    disk    ATA      MM1000GFJTE      HPG5  /dev/sda
[7:0:0:0]    disk    Nimble   Server           1.0   /dev/sdb
[root@host ~]#
```
