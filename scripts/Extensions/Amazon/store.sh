#!/bin/bash

# Register actions with the junk-store.sh script
ACTIONS+=()

# Register Amazon as a platform with the junk-store.sh script
PLATFORMS+=("Amazon")


# only source the settings if the platform is Amazon - this is to avoid conflicts with other plugins
if [[ "${PLATFORM}" == "Amazon" ]]; then
    source "${DECKY_PLUGIN_RUNTIME_DIR}/scripts/${Extensions}/Amazon/settings.sh"
fi

function Amazon_init() {
    $AMAZONCONF --list --dbfile $DBFILE $OFFLINE_MODE  &> /dev/null
}
function Amazon_refresh() {
    TEMP=$(Amazon_init)
    echo "{\"Type\": \"RefreshContent\", \"Content\": {\"Message\": \"Refreshed\"}}"
}
function Amazon_getgames(){
    if [ -z "${1}" ]; then
        FILTER=""
    else
        FILTER="${1}"
    fi
    if [ -z "${2}" ]; then
        INSTALLED="false"
    else
        INSTALLED="${2}"
    fi
     if [ -z "${3}" ]; then
        LIMIT="true"
    else
        LIMIT="${3}"
    fi
    IMAGE_PATH=""
    TEMP=$($AMAZONCONF --getgameswithimages "${IMAGE_PATH}" "${FILTER}" "${INSTALLED}" "${LIMIT}" "true" --dbfile $DBFILE)
    # This might be a bit fragile, but it should work for now.
    # checking if the Game's content is empty, if it is, then we need to refresh the list
    echo $TEMP >> $DECKY_PLUGIN_LOG_DIR/debug.log
    if echo "$TEMP" | jq -e '.Content.Games | length == 0' &>/dev/null; then
        if [[ $FILTER == "" ]] && [[ $INSTALLED == "false" ]]; then
            TEMP=$(Amazon_init)
            TEMP=$($AMAZONCONF --getgameswithimages "${IMAGE_PATH}" "${FILTER}" "${INSTALLED}" "${LIMIT}" "true" --dbfile $DBFILE)
        fi
    fi
    echo $TEMP
}
function Amazon_saveplatformconfig(){
    cat | $AMAZONCONF --parsejson "${1}" --dbfile $DBFILE --platform Proton --fork "" --version "" --dbfile $DBFILE
}
function Amazon_getplatformconfig(){
    TEMP=$($AMAZONCONF --confjson "${1}" --platform Proton --fork "" --version "" --dbfile $DBFILE)
    echo $TEMP
}
function Amazon_cancelinstall(){
    PID=$(cat "${DECKY_PLUGIN_LOG_DIR}/${1}.pid")
    PROGRESS_LOG="${DECKY_PLUGIN_LOG_DIR}/${1}.progress"
    killall -w nile
    grep -m 1 '^\[cli\] INFO: Download size:' $PROGRESS_LOG > "${DECKY_PLUGIN_LOG_DIR}/tmp" && mv "${DECKY_PLUGIN_LOG_DIR}/tmp" $PROGRESS_LOG
    rm "${DECKY_PLUGIN_LOG_DIR}/tmp.pid"
    rm "${DECKY_PLUGIN_LOG_DIR}/${1}.pid"
    echo "{\"Type\": \"Success\", \"Content\": {\"Message\": \"${1} installation Cancelled\"}}"
}
function Amazon_download(){
    PROGRESS_LOG="${DECKY_PLUGIN_LOG_DIR}/${1}.progress"
    GAME_DIR=$($AMAZONCONF --get-game-dir "${1}" --dbfile $DBFILE $OFFLINE_MODE)
    $NILE install $1 --base-path "${INSTALL_DIR}" --max-workers 10 >> "${DECKY_PLUGIN_LOG_DIR}/${1}.log" &> $PROGRESS_LOG &
    echo $! > "${DECKY_PLUGIN_LOG_DIR}/${1}.pid"
    echo "{\"Type\": \"Progress\", \"Content\": {\"Message\": \"Downloading\"}}"

}
function Amazon_update(){
    PROGRESS_LOG="${DECKY_PLUGIN_LOG_DIR}/${1}.progress"
    $NILE update $1 --max-workers 10 >> "${DECKY_PLUGIN_LOG_DIR}/${1}.log" 2>> $PROGRESS_LOG &
    echo $! > "${DECKY_PLUGIN_LOG_DIR}/${1}.pid"
    echo "{\"Type\": \"Progress\", \"Content\": {\"Message\": \"Updating\"}}"

}
function Amazon_verify(){
    PROGRESS_LOG="${DECKY_PLUGIN_LOG_DIR}/${1}.progress"
    $NILE verify $1 --max-workers 10 >> "${DECKY_PLUGIN_LOG_DIR}/${1}.log" 2>> $PROGRESS_LOG &
    echo $! > "${DECKY_PLUGIN_LOG_DIR}/${1}.pid"
    echo "{\"Type\": \"Progress\", \"Content\": {\"Message\": \"Updating\"}}"

}
function Amazon_protontricks(){
    get_steam_env
    unset STEAM_RUNTIME_LIBRARY_PATH
    export PROTONTRICKS_GUI=yad
    
    ARGS="--verbose $2 --gui &> \\\"${DECKY_PLUGIN_LOG_DIR}/${1}.log\\\""
    launchoptions "${PROTON_TRICKS}"  "${ARGS}" "${3}" "Protontricks" false ""
}
#this needs more thought
function Amazon_import(){
    PROGRESS_LOG="${DECKY_PLUGIN_LOG_DIR}/${1}.progress"
    GAME_DIR=$($AMAZONCONF --get-game-dir "${1}" --dbfile $DBFILE $OFFLINE_MODE)
    if [ -d "${GAME_DIR}" ]; then
        $NILE import $1 "${GAME_DIR}" $OFFLINE_MODE >> "${DECKY_PLUGIN_LOG_DIR}/${1}.log" 2>> $PROGRESS_LOG &
        echo $! > "${DECKY_PLUGIN_LOG_DIR}/${1}.pid"
        if [ $? -ne 0 ]; then
            move $1 > /dev/null
        fi
       
    fi  
    echo "{\"Type\": \"Progress\", \"Content\": {\"Message\": \"Updating\"}}"

}
function Amazon_update-umu-id(){
    TEMP=$($AMAZONCONF --update-umu-id "${1}" amazon --dbfile $DBFILE)
    echo "{\"Type\": \"Success\", \"Content\": {\"Message\": \"Umu Id updated\"}}"
}
function Amazon_install(){
    PROGRESS_LOG="${DECKY_PLUGIN_LOG_DIR}/${1}.progress"
    rm $PROGRESS_LOG &>> ${DECKY_PLUGIN_LOG_DIR}/${1}.log
    RESULT=$($AMAZONCONF --addsteamclientid "${1}" "${2}" --dbfile $DBFILE)
    TEMP=$($AMAZONCONF --update-umu-id "${1}" amazon --dbfile $DBFILE)
    mkdir -p "${HOME}/Games/amazon/"
    ARGS=$($ARGS_SCRIPT "${1}")
    TEMP=$($AMAZONCONF --launchoptions "${1}" "${ARGS}" "" --dbfile $DBFILE $OFFLINE_MODE)
    echo $TEMP
    exit 0
}
function Amazon_getlaunchoptions(){
    ARGS=$($ARGS_SCRIPT "${1}")
    TEMP=$($AMAZONCONF --launchoptions "${1}" "${ARGS}" "" --dbfile $DBFILE $OFFLINE_MODE)
    echo $TEMP
    exit 0
}
function Amazon_uninstall(){
    WORKING_DIR=$($AMAZONCONF --get-game-dir "${1}")
    $NILE uninstall $1 $OFFLINE_MODE>> "${DECKY_PLUGIN_LOG_DIR}/${1}.log"

    # this should be fixed before used, it might kill the entire machine

    #echo "Working dir is ${WORKING_DIR}"
    #rm "${WORKING_DIR}/install.done"
    TEMP=$($AMAZONCONF --clearsteamclientid "${1}" --dbfile $DBFILE)
    echo $TEMP

}
function Amazon_getgamedetails(){
    IMAGE_PATH=""
    TEMP=$($AMAZONCONF --getgamedata "${1}" "${IMAGE_PATH}" --dbfile $DBFILE --forkname "Proton" --version "null" --platform "Windows")
    echo $TEMP
    exit 0
}
function Amazon_getgamesize(){
    TEMP=$($AMAZONCONF --get-game-size "${1}" --dbfile $DBFILE)
    echo $TEMP
}
function Amazon_getprogress()
{
    TEMP=$($AMAZONCONF --getprogress "${DECKY_PLUGIN_LOG_DIR}/${1}.progress" --dbfile $DBFILE)
    echo $TEMP
}
function Amazon_loginstatus(){
    if [[ -z $1 ]]; then
        FLUSH_CACHE=""
    else 
        FLUSH_CACHE="--flush-cache"
    fi
    TEMP=$($AMAZONCONF --getloginstatus --dbfile $DBFILE --dbfile $DBFILE $OFFLINE_MODE $FLUSH_CACHE)
    echo $TEMP

}
function Amazon_run-exe(){
    get_steam_env  
    SETTINGS=$($AMAZONCONF --get-env-settings $ID --dbfile $DBFILE)
    eval "${SETTINGS}"
    STEAM_ID="${1}"
    GAME_SHORTNAME="${2}"
    GAME_EXE="${3}"
    ARGS="${4}"
    if [[ $4 == true ]]; then
        ARGS="some value"
    else
        ARGS=""
    fi
    COMPAT_TOOL="${5}"
    GAME_PATH=$($AMAZONCONF --get-game-dir $GAME_SHORTNAME --dbfile $DBFILE --offline)
    launchoptions "\\\"${GAME_PATH}/${GAME_EXE}\\\""  "${ARGS}  &> ${DECKY_PLUGIN_LOG_DIR}/run-exe.log" "${GAME_PATH}" "Run exe" true "${COMPAT_TOOL}"
}
function Amazon_get-exe-list(){
    get_steam_env
    STEAM_ID="${1}"
    GAME_SHORTNAME="${2}"
    GAME_PATH=$($AMAZONCONF --get-game-dir $GAME_SHORTNAME --dbfile $DBFILE --offline)
    export STEAM_COMPAT_DATA_PATH="${HOME}/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/${STEAM_ID}"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="${GAME_PATH}"
    cd "${STEAM_COMPAT_CLIENT_INSTALL_PATH}"
    LIST=$(find . \( -name "*.exe" -o -iname "*.bat" -o -iname "*.msi" \))
    JSON="{\"Type\": \"FileContent\", \"Content\": {\"PathRoot\": \"${GAME_PATH}\", \"Files\": ["
    for FILE in $LIST; do
        JSON="${JSON}{\"Path\": \"${FILE}\"},"
    done
    JSON=$(echo "$JSON" | sed 's/,$//')
    JSON="${JSON}]}}"
    echo $JSON
}
function launchoptions () {
    Exe=$1 
    Options=$2 
    WorkingDir=$3 
    Name=$4 
    Compatibility=$5
    CompatTooName=$6
    JSON="{\"Type\": \"RunExe\", \"Content\": {
        \"Exe\": \"${Exe}\",
        \"Options\": \"${Options}\",
        \"WorkingDir\": \"${WorkingDir}\",
        \"Name\": \"${Name}\",
        \"Compatibility\": \"${Compatibility}\",
        \"CompatToolName\": \"${CompatTooName}\"
    }}"
    echo $JSON
}
function Amazon_login(){
    get_steam_env
    launchoptions "${DECKY_PLUGIN_RUNTIME_DIR}/scripts/Extensions/Amazon/login.sh" "" "${DECKY_PLUGIN_LOG_DIR}" "Amazon Games Login" 
}
function loginlaunchoptions () {
    Exe=$1 
    Options=$2 
    WorkingDir=$3 
    Name=$4 
    Compatibility=$5
    CompatTooName=$6
    JSON="{\"Type\": \"LaunchOptions\", \"Content\": {
        \"Exe\": \"${Exe}\",
        \"Options\": \"${Options}\",
        \"WorkingDir\": \"${WorkingDir}\",
        \"Name\": \"${Name}\",
        \"Compatibility\": \"${Compatibility}\",
        \"CompatToolName\": \"${CompatTooName}\"
    }}"
    echo $JSON
}
function Amazon_login-launch-options(){
    get_steam_env
    loginlaunchoptions "${DECKY_PLUGIN_RUNTIME_DIR}/scripts/Extensions/Amazon/login.sh" "" "${DECKY_PLUGIN_LOG_DIR}" "Amazon Games Login" 
}
function Amazon_logout(){
    TEMP=$($NILE auth --logout)
    Amazon_loginstatus --flush-cache
}
function Amazon_getsetting(){
    TEMP=$($AMAZONCONF --getsetting $1 --dbfile $DBFILE)
    echo $TEMP
}
function Amazon_savesetting(){
    $AMAZONCONF --savesetting $1 $2 --dbfile $DBFILE
}   
function Amazon_getjsonimages(){
    
    TEMP=$($AMAZONCONF --get-base64-images "${1}" --dbfile $DBFILE --offline)
    echo $TEMP
}
function Amazon_gettabconfig(){
# Check if conf_schemas directory exists, create it if not
    if [[ ! -d "${DECKY_PLUGIN_RUNTIME_DIR}/conf_schemas" ]]; then
        mkdir -p "${DECKY_PLUGIN_RUNTIME_DIR}/conf_schemas"
    fi
    if [[ -f "${DECKY_PLUGIN_RUNTIME_DIR}/conf_schemas/amazontabconfig.json" ]]; then
        TEMP=$(cat "${DECKY_PLUGIN_RUNTIME_DIR}/conf_schemas/amazontabconfig.json")
    else
        TEMP=$(cat "${DECKY_PLUGIN_DIR}/conf_schemas/amazontabconfig.json")
    fi
    echo "{\"Type\":\"IniContent\", \"Content\": ${TEMP}}"
}
function Amazon_savetabconfig(){
    
    cat > "${DECKY_PLUGIN_RUNTIME_DIR}/conf_schemas/amazontabconfig.json"
    echo "{\"Type\": \"Success\", \"Content\": {\"Message\": \"Amazon tab config saved\"}}"
    
}