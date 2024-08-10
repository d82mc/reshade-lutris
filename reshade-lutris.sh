#!/bin/bash
cat > /dev/null <<LICENSE
    Copyright (C) 2021-2024  kevinlekiller, d82mc

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
    https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html
LICENSE
cat > /dev/null <<DESCRIPTION
    This is mostly a rewrite of kevinlekiller's reshade-steam-proton.sh.
    Everything related to proton was removed and replaced with the plain wine equivalent.
    There is no longer a requirement for a .dll override to be created.

    Environment Variables:
        MAIN_PATH
            By default, ReShade / shader files are stored in ~/.reshade
            You can override this by setting the MAIN_PATH variable, for example: MAIN_PATH=~/Documents/reshade ./reshade-steam-proton.sh

    Reuirements:
        grep
        curl
        wget
        protontricks
        git

    Notes:
        This installer works by:
            - Running the latest vulkan installer in the specified wine prefix
            - Running the latest reshade installer in the specified wine prefix

    Usage:
        Download the script
            Using wget:
                wget https://github.com/kevinlekiller/reshade-steam-proton/raw/main/reshade-lutris.sh
            Using git:
                git clone https://github.com/kevinlekiller/reshade-steam-proton
                cd reshade-steam-proton
        Make it executable:
            chmod u+x reshade-lutris.sh
        Run it:
            ./reshade-lutris.sh

        Installing ReShade for a game:
            Example on Cemu:

                If the game has never been run, run it.
                Exit the game.

                Find the Exe path:
                Ex: /home/kevin/Downloads/Cemu_2.0-88

                Find the Wine Prefix path:
                I recommend using a new wineprefix. You can create them through winetricks.
                Lutris has a winetricks button if you aren't used to the terminal invocation.
                Folder will contain a file user.reg.
                Ex: /home/deck/.var/app/net.lutris.Lutris/data/wineprefixes/Default/

                Find the wine Runner path:
                This will end in /bin and will contain a binary file called 'wine'.
                In testing, lutris-7.2-2-x86_64 worked great for the installation.
                (it can be different from the runner than Lutris is configured to use)
                Ex: /home/deck/.var/app/net.lutris.Lutris/data/lutris/runners/wine/lutris-7.2-2-x86_64/bin

                Run this script.

                Supply the 3 directories, when asked.

                Proceed through the Vulkan installer (launched as a subprocess)

                Proceed through the reshade installer (launched as a subprocess)

                You're done!

                Run the game, set the Effects and Textures search paths in the ReShade settings.

        Uninstalling ReShade for a game:
            Run this script as you normally would.

            When you reach the portion that runs the Reshade installer, select unintall/remove.

        Removing ReShade / shader files:
            By default the files are stored in ~/.reshade
            Run: rm -rf ~/.reshade
DESCRIPTION

function printErr() {
    if [[ -d $tmpDir ]]; then
        rm -rf "$tmpDir"
    fi
    echo -e "Error: $1\nExiting."
    [[ -z $2 ]] && exit 1 || exit "$2"
}

function checkStdin() {
    while true; do
        read -rp "$1" userInput
        if [[ $userInput =~ $2 ]]; then
            break
        fi
    done
    echo "$userInput"
}


function getGamePath() {
    echo 'Supply the folder path where the main executable (exe file) for the game is.'
    echo 'On default steam settings, look in ~/.local/share/Steam/steamapps/common/'
    while true; do
        read -rp 'Game path: ' gamePath
        eval gamePath="$gamePath"
        gamePath=$(realpath "$gamePath")

        if ! ls "$gamePath" > /dev/null 2>&1 || [[ -z $gamePath ]]; then
            echo "Incorrect or empty path supplied. You supplied \"$gamePath\"."
            continue
        fi

        if ! ls "$gamePath/"*.exe > /dev/null 2>&1; then
            echo "No .exe file found in \"$gamePath\"."
            echo "Do you still want to use this directory?"
            if [[ $(checkStdin "(y/n): " "^(y|n)$") != "y" ]]; then
                continue
            fi
        fi

        echo "Is this path correct? \"$gamePath\""
        if [[ $(checkStdin "(y/n): " "^(y|n)$") == "y" ]]; then
            break
        fi
    done
}

function getRunnerPath() {
    echo 'Supply the path where the wine runner you want to use is.'
    echo 'Ex: /home/deck/.var/app/net.lutris.Lutris/data/lutris/runners/wine/lutris-7.2-2-x86_64/bin'
    while true; do
        read -rp 'Runner path: ' runnerPath
        eval runnerPath="$runnerPath"
        runnerPath=$(realpath "$runnerPath")

        if ! ls "$runnerPath" > /dev/null 2>&1 || [[ -z $runnerPath ]]; then
            echo "Incorrect or empty path supplied. You supplied \"$runnerPath\"."
            continue
        fi

        if ! ls "$runnerPath/"wine > /dev/null 2>&1; then
            echo "No wine runner found in \"$runnerPath\"."
            echo "Do you still want to use this directory?"
            if [[ $(checkStdin "(y/n): " "^(y|n)$") != "y" ]]; then
                continue
            fi
        fi

        echo "Is this path correct? \"$runnerPath\""
        if [[ $(checkStdin "(y/n): " "^(y|n)$") == "y" ]]; then
            break
        fi
    done
}

function getPrefixPath() {
    echo -e "$SEPARATOR\nPlease supply the path of the wine prefix you will use to run the game."
    echo "Using winetricks in the lutris flatpak will create these at /home/deck/.var/app/net.lutris.Lutris/data/wineprefixes/"
    echo "The correct path will contain a user.reg file)."
    echo '(Control+c to exit)'
    while true; do
        read -rp 'Prefix path: ' prefixPath
        eval prefixPath="$prefixPath"
        prefixPath=$(realpath "$prefixPath")
        SteamID=0

        if ! ls "$prefixPath" > /dev/null 2>&1 || [[ -z $prefixPath ]]; then
            echo "Incorrect or empty path supplied. You supplied \"$prefixPath\"."
            continue
        fi

        if ! ls "$prefixPath/"user.reg > /dev/null 2>&1; then
            echo "No user.reg file found in \"$prefixPath\"."
            echo "Do you still want to use this directory?"
            if [[ $(checkStdin "(y/n): " "^(y|n)$") != "y" ]]; then
                continue
            fi
        fi

        echo "Is this path correct? \"$prefixPath\""
        if [[ $(checkStdin "(y/n): " "^(y|n)$") == "y" ]]; then
            break
        fi
    done
}

function setupReShadeFiles() {
    echo -e "$SEPARATOR\nLinking ReShade files to game directory."

    presetPath="${PRESETS_PATH}/${SteamID}.ini"
    logPath="${LOGS_PATH}/${SteamID}.log"

    touch "$(realpath $presetPath)"
    touch "$(realpath $logPath)"

    ln -is "$(realpath $INI_PATH)"   "$gamePath/ReShade.ini"
    ln -is "$(realpath $presetPath)" "$gamePath/ReShadePreset.ini"
    ln -is "$(realpath $logPath)"    "$gamePath/ReShade.log"
    ln -is "$(realpath "$MAIN_PATH"/reshade-shaders/Textures)" "$gamePath/"
    ln -is "$(realpath "$MAIN_PATH"/reshade-shaders/Shaders)"  "$gamePath/"
}

function installVulkan() {
    cd "$DL_PATH"

    echo -e "$SEPARATOR\nGetting latest Vulkan version..."

    LATEST_VULKAN_VER=$(curl -s https://vulkan.lunarg.com/sdk/latest/windows.json | grep -Po "\d+\.\d+\.\d+\.\d+")

    if [[ $? != 0 ]]; then
        printErr "Could not get latest Vulkan version."
    fi

    echo "Latest Vulkan version is: $LATEST_VULKAN_VER"

    echo -e "$SEPARATOR\nDownloading latest Vulkan Runtime..."
    VULKAN_RT_INSTALLER="VulkanRT-$LATEST_VULKAN_VER-Installer.exe"

    if [[ ! -f $VULKAN_RT_INSTALLER ]]; then
        curl -sLO https://sdk.lunarg.com/sdk/download/$LATEST_VULKAN_VER/windows/$VULKAN_RT_INSTALLER \
        || printErr "Could not download latest Vulkan Runtime."
    else
        echo "Latest version already downloaded."
    fi

    echo -e "\nInstalling latest Vulkan Runtime..."

    export WINEPREFIX=$prefixPath
    export WINEESYNC=1
    export WINEFSYNC=1
    export WINEDEBUG=-all
    "$runnerPath/wineserver" -k
    "$runnerPath/wine" "$DL_PATH/$VULKAN_RT_INSTALLER" | cat & pid=$! \
    || printErr "Could not install latest Vulkan Runtime. If all else fails, try a different Wine Runner!"\

    echo -e "$SEPARATOR\nPlease proceed with the Vulkan Installation"
    wait $pid

    if [[ $? == 0 ]]; then
        echo "Done Installing Vulkan."
    else
        echo "An error has occured."
        exit 1
    fi
}

function installReshade() {
    cd "$DL_PATH"

    RVERS=$(curl -sL https://reshade.me | grep -Po "downloads/ReShade_Setup_[\d.]+\_Addon.exe" | head -n1)
    RESHADE_INSTALLER="${RVERS##*/}"

    echo -e "\nDownloading Latest Reshade"
    echo -e "\nIf you experience a long FastFail error during the install, try running the script again. Wine is weird"
    if [[ ! -f $RESHADE_INSTALLER ]]; then
        echo "https://reshade.me/${RVERS}"
        curl -sLO "https://reshade.me/${RVERS}" || printErr "Could not download latest version of ReShade."

        echo "Successfully Downloaded $exeFile"

    else
        echo "${RESHADE_INSTALLER} already downloaded."
    fi

    echo -e "\nInstalling ${RESHADE_INSTALLER}..."

    export WINEPREFIX=$prefixPath
    export WINEESYNC=1
    export WINEFSYNC=1
    export WINEDEBUG=-all
    "$runnerPath/wine" "$DL_PATH/$RESHADE_INSTALLER" | cat & pid=$! \
    || printErr "Could not run the ReShade Installer. If all else fails, try a different Wine Runner!"\

    echo -e "$SEPARATOR\nPlease proceed with the ReShade Installation"
    echo "Navigate to your game executable in the installer,"
    echo "Select 'Vulkan'"
    echo "And select 'Update Only'"
    wait $pid

    if [[ $? == 0 ]]; then
        wait $!
        echo "Done Installing ReShade."
    else
        echo "An error has occured."
        exit 1
    fi
}

SEPARATOR="------------------------------------------------------------------------------------------------"

echo -e "$SEPARATOR\nReShade installer for Lutris (Vulkan Only) on Linux.\n$SEPARATOR\n"

MAIN_PATH=${MAIN_PATH:-~/".reshade"}
MAIN_PATH="$(realpath $MAIN_PATH)"
RESHADE_PATH="$MAIN_PATH/reshade"
RESHADE_SHADERS_PATH="$MAIN_PATH/reshade-shaders"
SHADER_REPOS_PATH="$MAIN_PATH/shader-repos"
RESHADE_DEFAULT_SHADERS_PATH="$SHADER_REPOS_PATH/reshade-shaders"
INI_PATH="$MAIN_PATH/ReShade.ini"
LOGS_PATH="$MAIN_PATH/logs"
PRESETS_PATH="$MAIN_PATH/presets"

DL_PATH="/home/$USER/Downloads"

mkdir -p "$MAIN_PATH" || printErr "Unable to create directory '$MAIN_PATH'."
cd "$MAIN_PATH" || exit

mkdir -p "$RESHADE_PATH"      || printErr "Unable to create directory '$RESHADE_PATH'."
mkdir -p "$SHADER_REPOS_PATH" || printErr "Unable to create directory '$SHADER_REPOS_PATH'."
mkdir -p "$PRESETS_PATH"      || printErr "Unable to create directory '$PRESETS_PATH'."
mkdir -p "$LOGS_PATH"         || printErr "Unable to create directory '$LOGS_PATH'."

mkdir -p "$RESHADE_SHADERS_PATH/Shaders"  || printErr "Unable to create directory '$RESHADE_SHADERS_PATH/Shaders'."
mkdir -p "$RESHADE_SHADERS_PATH/Textures" || printErr "Unable to create directory '$RESHADE_SHADERS_PATH/Textures'."

#create default ReShade.ini if needed
if [[ ! -f $INI_PATH ]]; then
    echo -e "[GENERAL]\nEffectSearchPaths=.\Shaders\**\nTextureSearchPaths=.\Textures\**" > "$INI_PATH" \
    || printErr "While trying to create the default ReShade.ini."
    unix2dos "$INI_PATH" 2>/dev/null 1>/dev/null \
    || printErr "While trying to create the default ReShade.ini."
fi

#install default ReShade shaders if not already installed
if [[ ! -d "$RESHADE_DEFAULT_SHADERS_PATH" ]]; then
    echo -e "Installing default ReShade shaders.\n$SEPARATOR"
    cd "$SHADER_REPOS_PATH"
    git clone --branch slim https://github.com/crosire/reshade-shaders \
    || printErr "Unable to clone https://github.com/crosire/reshade-shaders"
fi

cd "$MAIN_PATH"

getGamePath

getPrefixPath

getRunnerPath

installVulkan

installReshade

checkStdin "Press enter once the ReShade installer is finished"

setupReShadeFiles

echo -e "$SEPARATOR\nAll Done!"

echo "Note: By default this installer will download the Reshade with Addon support. This enables depth3d fx such as quint_SSR."
echo "You may notice crashes related to the depth buffers. If you don't care about depth3d and you experience crashes in-game,"
echo "try disabling generic depth and effect runtime sync in the addons tab."
