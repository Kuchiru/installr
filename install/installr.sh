#!/bin/bash

# installr.sh
# A script to (optionally) erase a volume and install macos and
# additional packagesfound in a packages folder in the same directory
# as this script

if [[ $EUID != 0 ]] ; then
    echo "installr: Please run this as root, or via sudo."
    exit -1
fi

until [[ $(/usr/bin/pmset -g ps) == *"AC Power"* ]]; do
    echo "Please connect a Power Adapter to continue.."
    sleep 5
done

INDEX=0
OLDIFS=$IFS
IFS=$'\n'

# dirname and basename not available in Recovery boot
# so we get to use Bash pattern matching
BASENAME=${0##*/}
THISDIR=${0%$BASENAME}
PACKAGESDIR="${THISDIR}packages"
INSTALLERDIR="${THISDIR}installers"


echo "****** Welcome to installr! ******"
echo 
echo "Available Installers:"
for ITEM in "${INSTALLERDIR}"/* ; do
    let INDEX=${INDEX}+1
    INSTALLERS[${INDEX}]=${ITEM}
    echo "    ${INDEX}.  ${ITEM##*/}"
done
read -p "Select which Installer you would like to use # (1-${INDEX}): " SELECTEDINDEX

SELECTEDINSTALLER=${INSTALLERS[${SELECTEDINDEX}]}

if [[ "${SELECTEDINSTALLER}" == "" ]]; then
    exit 0
fi

INDEX=0
echo 
echo "Available package directories:"
for ITEM in "${PACKAGESDIR}"/* ; do
    let INDEX=${INDEX}+1
    PACKAGES[${INDEX}]=${ITEM}
    echo "    ${INDEX}  ${ITEM##*/}"
done
echo 
read -p "Select which package directory you would like to use # (1-${INDEX}): " SELECTEDINDEX

SELECTEDPACKAGESDIR=${PACKAGES[${SELECTEDINDEX}]}

if [[ "${SELECTEDPACKAGESDIR}" == "" ]]; then
    exit 0
fi

INDEX=0
echo "Available volumes:"
for VOL in $(/bin/ls -1 /Volumes) ; do
    if [[ "${VOL}" != "OS X Base System" ]] ; then
        let INDEX=${INDEX}+1
        VOLUMES[${INDEX}]=${VOL}
        echo "    ${INDEX}  ${VOL}"
    fi
done
read -p "Install to volume # (1-${INDEX}): " SELECTEDINDEX

SELECTEDVOLUME=${VOLUMES[${SELECTEDINDEX}]}

if [[ "${SELECTEDVOLUME}" == "" ]]; then
    exit 0
fi

read -p "Erase target volume before install (y/N)? " ERASETARGET

case ${ERASETARGET:0:1} in
    [yY] ) /usr/sbin/diskutil reformat "/Volumes/${SELECTEDVOLUME}" ;;
    * ) echo ;;
esac

echo
echo "Installing macOS to /Volumes/${SELECTEDVOLUME}..."

# build our startosinstall command
STARTOSINSTALL=$(echo ${SELECTEDINSTALLER}/Contents/Resources/startosinstall)

CMD="\"${STARTOSINSTALL}\" --agreetolicense --volume \"/Volumes/${SELECTEDVOLUME}\"" 

for ITEM in "${SELECTEDPACKAGESDIR}"/* ; do
    FILENAME="${ITEM##*/}"
    EXTENSION="${FILENAME##*.}"
    if [[ -e ${ITEM} ]]; then
        case ${EXTENSION} in
            pkg ) CMD="${CMD} --installpackage \"${ITEM}\"" ;;
            * ) echo "    ignoring non-package ${ITEM}..." ;;
        esac
    fi
done

# kick off the OS install
eval $CMD

