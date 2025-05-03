#!/bin/bash
AMAZONCONF="${DECKY_PLUGIN_RUNTIME_DIR}/scripts/Extensions/Amazon/amazon-config.py"
export NILE="/bin/flatpak run com.github.imlinguin.nile"
PROTON_TRICKS="/bin/flatpak run com.github.Matoking.protontricks"
# the launcher script to use in steam
export PYTHONPATH="${DECKY_PLUGIN_DIR}/scripts/":"${DECKY_PLUGIN_DIR}/scripts/shared/":"${DECKY_PLUGIN_RUNTIME_DIR}/scripts/${Extensions}/Amazon/":$PYTHONPATH

export LAUNCHER="${DECKY_PLUGIN_RUNTIME_DIR}/scripts/${Extensions}/Amazon/amazon-launcher.sh"
export ARGS_SCRIPT="${DECKY_PLUGIN_RUNTIME_DIR}/scripts/${Extensions}/Amazon/get-amazon-args.sh"

DBNAME="amazon.db"
# database to use for configs and metadata
DBFILE="${DECKY_PLUGIN_RUNTIME_DIR}/amazon.db"

if [[ -f "${DECKY_PLUGIN_RUNTIME_DIR}/conf_schemas/amazontabconfig.json" ]]; then
    TEMP="${DECKY_PLUGIN_RUNTIME_DIR}/conf_schemas/amazontabconfig.json"
else
    TEMP="${DECKY_PLUGIN_DIR}/conf_schemas/amazontabconfig.json"
fi
SETTINGS=$($AMAZONCONF --generate-env-settings-json $TEMP --dbfile $DBFILE)
eval "${SETTINGS}"


if [[ "${AMAZON_OFFLINEMODE}" == "true" ]]; then
    OFFLINE_MODE="--offline"
else
    OFFLINE_MODE=""
fi
if [[ "${AMAZON_INSTALLLOCATION}" == "SSD" ]]; then
    INSTALL_DIR="${HOME}/Games/amazon/"
elif [[ "${AMAZON_INSTALLLOCATION}" == "MicroSD" ]]; then
    NVME=$(lsblk --list | grep nvme0n1\ |awk '{ print $2}' |  awk '{split($0, a,":"); print a[1]}')
    LINK=$(find /run/media -maxdepth 1  -type l )
    LINK_TARGET=$(readlink -f "${LINK}")
    MOUNT_PONT=$(lsblk --list --exclude "${NVME}" | grep part | cut -d \  -f 11-)
    if [[ $MOUNT_PONT == $LINK_TARGET ]]; then
        INSTALL_DIR="${LINK}/Games/amazon/"
    else    
        INSTALL_DIR="/run/media/mmcblk0p1/Games/amazon/"
    fi
else
    INSTALL_DIR="${HOME}/Games/"
fi
mkdir -p "${INSTALL_DIR}"

export INSTALL_DIR
