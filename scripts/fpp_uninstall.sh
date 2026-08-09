#!/bin/bash

# fpp-splash uninstall script - removes the service, keeps the config file
# so settings survive a reinstall.

sudo systemctl disable --now fpp-splash.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/fpp-splash.service
sudo systemctl daemon-reload

# Blank the framebuffer so a stale splash isn't left on screen
dd if=/dev/zero of=/dev/fb0 bs=64k 2>/dev/null || true

echo "fpp-splash: uninstalled."
