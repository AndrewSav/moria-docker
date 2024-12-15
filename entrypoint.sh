#!/bin/bash

s=/mnt/moria/server
p=/mnt/moria/server/Moria/Saved

mkdir -p /root/.steam 2>&1

echo "[entrypoint] Updating Return to Moria  Dedicated Server files..."
/usr/bin/steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$s" +login "${steamuser}" +app_update 3349480 validate +quit

echo "[entrypoint] Removing /tmp/.X0-lock..."
rm -f /tmp/.X0-lock 2>&1

echo "[entrypoint] Re(setting) invite seed..."
echo -n "${inviteseed}" >  ${p}/Config/InviteSeed.cfg

echo "[entrypoint] Launching wine64 Return to Moria..."
exec xvfb-run wine64 "${s}/MoriaServer.exe" 2>&1