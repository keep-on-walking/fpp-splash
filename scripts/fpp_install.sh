#!/bin/bash
set -e

# fpp-splash install script
# Installs a systemd service that keeps the splash daemon running across
# reboots. Config lives in /home/fpp/media/config/plugin.fpp-splash.json
# and is editable from Content Setup -> Idle Splash.

. ${FPPDIR}/scripts/common

PLUGDIR="$(cd "$(dirname "$0")/.." && pwd)"
chmod +x "$PLUGDIR/scripts/"*.sh

CONFIG=/home/fpp/media/config/plugin.fpp-splash.json
if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" << 'CFGEOF'
{
    "mode": "text",
    "text": "Welcome",
    "paused_text": "PAUSED",
    "pointsize": "100",
    "fg": "white",
    "bg": "black",
    "font": "Nimbus-Sans-Bold-Italic",
    "image": ""
}
CFGEOF
fi

sed "s|@PLUGDIR@|$PLUGDIR|" "$PLUGDIR/fpp-splash.service" | sudo tee /etc/systemd/system/fpp-splash.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now fpp-splash.service

echo "fpp-splash: installed and running. Configure under Content Setup -> Idle Splash."
