#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 mazzarol
set -euo pipefail

# ── NFC Implant Login — installer ──
# Repository: https://github.com/mazzarol/nfc-implant-login.git
# NFC Implants: https://dangerousthings.com
# Tested on: Ubuntu 24.04.4 LTS (Noble Numbat)
# Run: sudo ./install.sh YOUR_USERNAME "04 11 22 33 44 55 66" ["04 AA BB CC DD EE FF" ...]

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
DIR="$(cd "$(dirname "$0")" && pwd)"

USERNAME="${1:-}"
UID1="${2:-}"
UID2="${3:-}"
UID3="${4:-}"

if [ -z "$USERNAME" ] || [ -z "$UID1" ]; then
    echo "Usage: sudo ./install.sh USERNAME \"UID1\" [\"UID2\"] [\"UID3\"]"
    echo "Example: sudo ./install.sh peter \"04 11 22 33 44 55 66\" \"04 AA BB CC DD EE FF\""
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

echo -e "${CYAN}═══ NFC Implant Login Installer ═══${NC}"
echo "User: $USERNAME"
echo

# ── 1. Install dependencies ──
echo -e "${GREEN}[1/7]${NC} Installing packages..."
apt-get update -qq
apt-get install -y -qq pcscd pcsc-tools python3-pyscard libacsccid1 2>&1 | tail -1

# ── 2. Install scripts ──
echo -e "${GREEN}[2/7]${NC} Installing auth scripts..."
cp "$DIR/nfc-check" /usr/local/bin/nfc-check
chmod 755 /usr/local/bin/nfc-check

HOME_DIR=$(getent passwd "$USERNAME" | cut -d: -f6)
if [ -n "$HOME_DIR" ] && [ "$HOME_DIR" != "/nonexistent" ]; then
    mkdir -p "$HOME_DIR/.local/bin"
    cp "$DIR/nfc-unlockd" "$HOME_DIR/.local/bin/nfc-unlockd"
    chmod 755 "$HOME_DIR/.local/bin/nfc-unlockd"
    chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.local/bin"
fi

# ── 3. Create auth config ──
echo -e "${GREEN}[3/7]${NC} Creating /etc/nfc-auth.conf..."
UIDS="\"$UID1\""
[ -n "$UID2" ] && UIDS="$UIDS, \"$UID2\""
[ -n "$UID3" ] && UIDS="$UIDS, \"$UID3\""
echo "{\"$USERNAME\": [$UIDS]}" > /etc/nfc-auth.conf
chmod 644 /etc/nfc-auth.conf

# ── 4. pcscd persistent ──
echo -e "${GREEN}[4/7]${NC} Configuring pcscd (persistent mode)..."
mkdir -p /etc/systemd/system/pcscd.service.d
cp "$DIR/pcscd-override.conf" /etc/systemd/system/pcscd.service.d/override.conf
systemctl daemon-reload
systemctl restart pcscd

# ── 5. udev rule ──
echo -e "${GREEN}[5/7]${NC} Installing udev rule (no USB suspend)..."
cp "$DIR/99-acr122u-nosuspend.rules" /etc/udev/rules.d/
udevadm control --reload-rules

# ── 6. PAM configuration ──
echo -e "${GREEN}[6/7]${NC} Configuring PAM..."

# GDM password
if ! grep -q "nfc-check" /etc/pam.d/gdm-password 2>/dev/null; then
    sed -i '/^auth.*required.*pam_succeed_if.*root/a auth\tsufficient\tpam_exec.so expose_authtok /usr/local/bin/nfc-check' /etc/pam.d/gdm-password
    echo "  + GDM login configured"
else
    echo "  - GDM login already configured"
fi

# Sudo
if ! grep -q "nfc-check" /etc/pam.d/sudo 2>/dev/null; then
    sed -i '/^@include common-auth/i auth\tsufficient\tpam_exec.so expose_authtok /usr/local/bin/nfc-check' /etc/pam.d/sudo
    echo "  + sudo configured"
else
    echo "  - sudo already configured"
fi

# ── 7. User systemd unlock daemon ──
echo -e "${GREEN}[7/7]${NC} Installing unlock daemon..."
if [ -n "$HOME_DIR" ] && [ "$HOME_DIR" != "/nonexistent" ]; then
    SVC_DIR="$HOME_DIR/.config/systemd/user"
    mkdir -p "$SVC_DIR"
    cp "$DIR/nfc-unlockd.service" "$SVC_DIR/"
    sed -i "s|/home/peter|$HOME_DIR|g" "$SVC_DIR/nfc-unlockd.service"
    chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.config"

    # Enable linger so user services survive logout
    loginctl enable-linger "$USERNAME" 2>/dev/null || true

    # Start daemon as the user
    sudo -u "$USERNAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$USERNAME")" \
        systemctl --user daemon-reload 2>/dev/null || true
    sudo -u "$USERNAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$USERNAME")" \
        systemctl --user enable --now nfc-unlockd.service 2>/dev/null || true

    echo "  + unlock daemon installed and started"
else
    echo "  ! Could not determine home directory — skipping daemon"
fi

# ── Done ──
echo
echo -e "${GREEN}═══ Installation complete ═══${NC}"
echo
echo "Next steps:"
echo "  1. Plug in your ACS ACR122U NFC reader"
echo "  2. Lock screen: Super+L"
echo "  3. Tap your implant — it should unlock instantly"
echo "  4. For cold-boot login: type any key + Enter + tap"
echo "  5. For sudo: tap + Enter (or enter password)"
echo
echo "Auth config:  /etc/nfc-auth.conf  (add UIDs here)"
echo "PAM scripts:  /usr/local/bin/nfc-check"
echo "Unlock daemon: systemctl --user status nfc-unlockd"
echo "Uninstall:    sudo $DIR/uninstall.sh $USERNAME"
