#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 mazzarol
set -euo pipefail
# ── NFC Implant Login — uninstaller ──
# Repository: https://github.com/mazzarol/nfc-host-login.git
# NFC Implants: https://dangerousthings.com
# Tested on: Ubuntu 24.04.4 LTS (Noble Numbat)

USERNAME="${1:-}"

if [ -z "$USERNAME" ]; then
    echo "Usage: sudo ./uninstall.sh USERNAME"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

echo "Uninstalling NFC Implant Login for user: $USERNAME"

# Stop and remove user daemon
HOME_DIR=$(getent passwd "$USERNAME" | cut -d: -f6)
if [ -n "$HOME_DIR" ] && [ "$HOME_DIR" != "/nonexistent" ]; then
    sudo -u "$USERNAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$USERNAME")" \
        systemctl --user stop nfc-unlockd.service 2>/dev/null || true
    sudo -u "$USERNAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$USERNAME")" \
        systemctl --user disable nfc-unlockd.service 2>/dev/null || true
    rm -f "$HOME_DIR/.config/systemd/user/nfc-unlockd.service"
    rm -f "$HOME_DIR/.local/bin/nfc-unlockd"
fi

# Remove scripts and config
rm -f /usr/local/bin/nfc-check
rm -f /etc/nfc-auth.conf

# Remove PAM lines
if [ -f /etc/pam.d/gdm-password.bak ]; then
    cp /etc/pam.d/gdm-password.bak /etc/pam.d/gdm-password
else
    sed -i '/nfc-check/d' /etc/pam.d/gdm-password 2>/dev/null || true
fi
sed -i '/nfc-check/d' /etc/pam.d/sudo 2>/dev/null || true

# Remove udev rule
rm -f /etc/udev/rules.d/99-acr122u-nosuspend.rules
udevadm control --reload-rules

# Remove pcscd override
rm -f /etc/systemd/system/pcscd.service.d/override.conf
systemctl daemon-reload
systemctl restart pcscd

echo "Done. NFC login removed. Password auth restored."
