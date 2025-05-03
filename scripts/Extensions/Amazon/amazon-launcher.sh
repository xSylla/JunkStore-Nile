#!/bin/bash
# These need to be exported because it does not get executed in the context of the plugin.
export DECKY_PLUGIN_RUNTIME_DIR="${HOME}/homebrew/data/Junk-Store"
export DECKY_PLUGIN_DIR="${HOME}/homebrew/plugins/Junk-Store"
export DECKY_PLUGIN_LOG_DIR="${HOME}/homebrew/logs/Junk-Store"
export WORKING_DIR=$DECKY_PLUGIN_DIR
export Extensions="Extensions"
ID=$1
echo $1
shift

source "${DECKY_PLUGIN_RUNTIME_DIR}/scripts/Extensions/Amazon/settings.sh"

echo "dbfile: ${DBFILE}"
SETTINGS=$($AMAZONCONF --get-env-settings $ID --dbfile $DBFILE --platform Proton --fork "" --version "" --dbfile $DBFILE)
echo "${SETTINGS}"
eval "${SETTINGS}"


if [[ "${RUNTIMES_ESYNC}" == "true" ]]; then
    export PROTON_NO_ESYNC=1
else
    export PROTON_NO_ESYNC=0
fi
if [[ "${RUNTIMES_FSYNC}" == "true" ]]; then
    export PROTON_NO_FSYNC=1
else
    export PROTON_NO_FSYNC=0
fi
if [[ "${RUNTIMES_VKD3D}" == "true" ]]; then
    export PROTON_USE_WINED3D=1
else
    export PROTON_USE_WINED3D=0
fi
if [[ "${RUNTIMES_VKD3D_PROTON}" == "true" ]]; then
    export PROTON_USE_WINED3D=0
    export PROTON_USE_WINED3D11=1
else
    export PROTON_USE_WINED3D11=0
fi
if [[ "RUNTIMES_FSR" == "true" ]]; then
    export WINE_FULLSCREEN_FSR=1
else
    export WINE_FULLSCREEN_FSR=0
fi
if [ -z "${RUNTIMES_FSR_STRENGTH}" ]; then
    unset WINE_FULLSCREEN_FSR_STRENGTH
else
    export WINE_FULLSCREEN_FSR_STRENGTH=${RUNTIMES_FSR_STRENGTH}
fi

if [[ "${RUNTIMES_LIMIT_FRAMERATE}" == "true" ]]; then
    export DXVK_FRAME_RATE=${RUNTIMES_FRAME_RATE}
fi

if [[ "${RUNTIMES_EASYANTICHEAT}" == "true" ]]; then
    echo "enabling easy anti cheat"
    export PROTON_EAC_RUNTIME="${HOME}/.steam/root/steamapps/common/Proton EasyAntiCheat Runtime/"
fi
if [[ "${RUNTIMES_BATTLEYE}" == "true"  ]]; then
    export PROTON_BATTLEYE_RUNTIME="${HOME}/.steam/root/steamapps/common/Proton BattlEye Runtime/"
fi

if [ -z "${RUNTIMES_PULSE_LATENCY_MSEC}" ]; then
    export PULSE_LATENCY_MSEC=$RUNTIMES_PULSE_LATENCY_MSEC

fi
if [[ "${RUNTIMES_RADV_PERFTEST}" == "" ]]; then
    unset RADV_PERFTEST
else
    export RADV_PERFTEST=$RUNTIMES_RADV_PERFTEST
fi


QUOTED_ARGS=""
ALL_BUT_LAST_ARG=""
for arg in "$@"; do
    QUOTED_ARGS+=" \"${arg}\""
    if [[ "${arg}" != "${!#}" ]]; then
        ALL_BUT_LAST_ARG+=" \"${arg}\""
    else
        ALL_BUT_LAST_ARG+=" \"install_deps.bat\""
    fi
   
done


ARGS=$("${ARGS_SCRIPT}" $ID)
echo "ARGS: ${ARGS}"
echo "ARGS: ${ARGS}" &>> "${DECKY_PLUGIN_LOG_DIR}/${ID}.log"
# for arg in $ARGS; do
#     QUOTED_ARGS+=" \"${arg}\""
# done
QUOTED_ARGS+=" ${ARGS}"

pushd "${DECKY_PLUGIN_DIR}"
GAME_PATH=$($AMAZONCONF --get-game-dir $ID --dbfile $DBFILE --offline)
popd
echo "game path: ${GAME_PATH}" &> "${GAME_PATH}/launcher.log"

if [ -f "${GAME_PATH}/install.done" ]; then
    echo "install_deps.bat exists"
    echo "install_deps.bat exists" &>> "${GAME_PATH}/launcher.log"
    pwd &>> "${GAME_PATH}/launcher.log"
else
    echo "installing deps" &>> "${GAME_PATH}/launcher.log"
    echo "install_deps.bat does not exist"
    pwd &>> "${GAME_PATH}/launcher.log"
    pushd "${DECKY_PLUGIN_DIR}" &>> "${GAME_PATH}/launcher.log"
    echo "${AMAZONCONF} --gen-install-deps \"${ID}\" \"${GAME_PATH}\" --dbfile ${DBFILE}" &>> "${GAME_PATH}/launcher.log"
    $AMAZONCONF --gen-install-deps "${ID}" "${GAME_PATH}" --dbfile $DBFILE &>> "${GAME_PATH}/launcher.log"
    popd


    echo "running install_deps.bat"
    pushd "${GAME_PATH}"

    echo "path: ${GAME_PATH}" &>> "${GAME_PATH}/launcher.log"
    eval "`echo -e $ALL_BUT_LAST_ARG`"  # &>> "${DECKY_PLUGIN_LOG_DIR}/${ID}.log"
    popd
fi

export STORE="amazon"
export UMU_ID=$($AMAZONCONF --get-umu-id $ID --dbfile $DBFILE)
export STEAM_COMPAT_INSTALL_PATH=${GAME_PATH}
export STEAM_COMPAT_LIBRARY_PATHS=${STEAM_COMPAT_LIBRARY_PATHS}:${GAME_PATH}
export PROTON_SET_GAME_DRIVE="gamedrive"

echo -e "Running: ${QUOTED_ARGS}"  # >> "${DECKY_PLUGIN_LOG_DIR}/${ID}.log"

eval "`echo -e ${QUOTED_ARGS}`"  # &>> "${DECKY_PLUGIN_LOG_DIR}/${ID}.log"

if [[ "${ADVANCED_GAMESCOPE_HACK}" == "true" ]]; then
    sleep $ADVANCED_GAMESCOPE_HACK_DELAY
    WIN_ORDER=$(xprop -d :0 -root | grep GAMESCOPE_FOCUSABLE_WINDOWS | cut -d "=" -f 2 |sed 's/, 769//g')

    xprop -d :0 -root -f GAMESCOPECTRL_BASELAYER_APPID 32co -set GAMESCOPECTRL_BASELAYER_APPID "${WIN_ORDER}, 769"
fi