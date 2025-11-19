#!/bin/bash

set -e

mkdir -p /root/.steam 2>&1

if [ -f /server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.bak ]; then
    echo "[entrypoint] Restoring patched MoriaServer-Win64-Shipping.exe for steam validation"
    rm -f /server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe
    mv /server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.bak /server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe
fi

if [ -z "$SKIP_UPDATE" ] || [ ! -f "/server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe" ]; then
    if [ -n "$SKIP_UPDATE" ] && [ ! -f "/server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe" ]; then
        echo "[entrypoint] SKIP_UPDATE is set but server files are missing. Forcing update..."
    fi
    echo "[entrypoint] Updating Return To Moria Dedicated Server files with steamcmd..."
    if ! (r=5; while ! /usr/bin/steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir /server +login anonymous +app_update 3349480 validate +quit ; do
              ((--r)) || exit
              echo "[entrypoint] something went wrong, let's wait 5 seconds and retry"
              rm -rf /server/steamapps
              sleep 5
          done) ; then
        echo "[entrypoint] failed updating with steamcmd!"
        exit 1
    fi
else
    echo "[entrypoint] Skipping update as SKIP_UPDATE is set"
fi

echo "[entrypoint] Patching subsystem in MoriaServer-Win64-Shipping.exe..."
patcher /server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe

echo "[entrypoint] Launching wine64 Return to Moria..."
exec wine64 "/server/Moria/Binaries/Win64/MoriaServer-Win64-Shipping.exe" Moria 2>&1
