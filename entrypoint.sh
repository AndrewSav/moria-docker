#!/bin/bash

set -e

# This block is here, so that we do not run the game as root
if [ "$(id -u)" = "0" ]; then
    echo "[entrypoint] Setting up permissions and dropping root privileges..."
    groupmod -o -g "${PGID:-1000}" steam
    usermod -o -u "${PUID:-1000}" steam
    chown -R steam:steam /server
    # When PUID matches the build-time uid (1000), symlink directly to the pre-built prefix in
    # the image. Wine writes go to the container overlay layer, which works fine in practice.
    # If this ever becomes an issue, remove the PUID check to always use the volume path below.
    if [ "${PUID:-1000}" = "1000" ]; then
        ln -s /wineprefix-template /home/steam/.wine
    else
        chown -R steam:steam /home/steam
        if [ "$(cat /wineprefix-volume/.timestamp 2>/dev/null)" != "$(cat /wineprefix-template/.timestamp)" ]; then
            echo "[entrypoint] Copying wine prefix to volume (first run or image upgrade)..."
            find /wineprefix-volume -mindepth 1 -delete
            cp -a /wineprefix-template/. /wineprefix-volume/
        fi
        chown -R steam:steam /wineprefix-volume
        ln -s /wineprefix-volume /home/steam/.wine
    fi
    exec gosu steam "$0" "$@"
fi

# This block is here, so that we support attaching to console
if [ -f /server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.bak ]; then
    echo "[entrypoint] Restoring patched MoriaServer-Win64-Shipping.exe for steam validation"
    rm -f /server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe
    mv /server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.bak /server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe
fi

# This block is here, so that we retry failed updates (happens to me quite reqularily) or skip updates altogether
if [ -z "$SKIP_UPDATE" ] || [ ! -f "/server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe" ]; then
    if [ -n "$SKIP_UPDATE" ] && [ ! -f "/server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe" ]; then
        echo "[entrypoint] SKIP_UPDATE is set but server files are missing. Forcing update..."
    fi
    echo "[entrypoint] Updating Return To Moria Dedicated Server files with steamcmd..."
    rm -rf /server/steamapps
    if ! (r=5; while ! /usr/bin/steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir /server +login anonymous +app_update 3349480 validate +quit ; do
              ((--r)) || exit
              echo "[entrypoint] something went wrong, let's wait 5 seconds and retry"
              sleep 5
          done) ; then
        echo "[entrypoint] failed updating with steamcmd!"
        exit 1
    fi
else
    echo "[entrypoint] Skipping update as SKIP_UPDATE is set"
fi

# This also is attaching to console support
echo "[entrypoint] Patching subsystem in MoriaServer-Win64-Shipping.exe..."
patcher /server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe

echo "[entrypoint] Launching wine Return to Moria..."
exec wine "/server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe" Moria "-NumServerWorkerThreads=${SERVER_WORKER_THREADS:-4}" 2>&1
