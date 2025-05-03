#!/bin/bash

function download_and_install() {
    flatpak --user install "${DECKY_PLUGIN_RUNTIME_DIR}/scripts/Extensions/Amazon/nile.flatpak" -y
}

function install() {

    if flatpak list | grep -q "com.github.imlinguin.nile"; then
        echo "nile flatpak is installed, removing and reinstalling"
        flatpak uninstall com.github.imlinguin.nile -y    
    fi

    download_and_install
}

function uninstall() {
    echo "Uninstalling flatpaks"
    if flatpak list | grep -q "com.github.imlinguin.nile"; then
        echo "nile flatpak is installed, removing"
        flatpak uninstall com.github.imlinguin.nile -y    
    fi
    echo "Removing unused flatpaks"
    flatpak uninstall --unused -y
}

if [ "$1" == "uninstall" ]; then
    echo "Uninstalling dependencies: Amazon extension"
    uninstall
else
    echo "Installing dependencies: Amazon extension"
    install
    chmod u+x "${DECKY_PLUGIN_RUNTIME_DIR}/scripts/Extensions/Amazon/*.sh"
    chmod u+x "${DECKY_PLUGIN_RUNTIME_DIR}/scripts/Extensions/Amazon/*.py"
fi
