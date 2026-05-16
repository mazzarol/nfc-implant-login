# NFC Implant Login

> **Author:** mazzarol  
> **Repository:** https://github.com/mazzarol/nfc-host-login.git  
> **NFC Implants by:** https://dangerousthings.com  
> **License:** [GPL-3.0-or-later](LICENSE)  
> **Tested on:** Ubuntu 24.04.4 LTS (noble)

Walk up to your Linux desktop, tap your NFC implant, and you're in.
No password, no typing, no Enter key.

## How it works

Two components:

**nfc-unlockd** — a background daemon that watches the NFC reader.
When you tap an authorized implant, it unlocks your GNOME session instantly.
Covers the 90% case: screen locked, walk up, tap, in.

**nfc-check** — a PAM module for GDM login and sudo.
Press Enter (any character) then tap your implant to authenticate.
Falls back to password if the reader is missing or broken.

## Requirements

- Linux with GNOME/GDM (Ubuntu 24.04.4 LTS Noble — tested)
- ACS ACR122U NFC reader (USB)
- NFC implant (NTAG216, DESFire, MIFARE Ultralight)
- Python 3, systemd, pcscd

## Quick Install

```bash
# 1. Plug in your ACR122U reader
# 2. Find your implant UIDs (use pcsc_scan or the included script)
sudo apt-get install pcscd pcsc-tools python3-pyscard
python3 -c "
from smartcard.System import readers
from smartcard.util import toHexString
r = readers()[0].createConnection()
r.connect()
resp, sw1, sw2 = r.transmit([0xFF, 0xCA, 0x00, 0x00, 0x00])
print(toHexString(resp))
"

# 3. Install
chmod +x install.sh uninstall.sh
sudo ./install.sh YOUR_USERNAME "04 11 22 33 44 55 66" "04 AA BB CC DD EE FF"

# 4. Test
# Lock screen: Super+L → tap implant → unlocked!
```

## Usage

| Action | Method |
|--------|--------|
| Unlock locked session | Tap implant on reader |
| Cold-boot GDM login | Type any key + Enter + tap implant |
| Sudo in terminal | Tap implant + Enter (or type password) |
| Reader broken/unplugged | Password login works normally |

## Files

```
nfc-implant-login/
├── install.sh                    # System installer (run with sudo)
├── uninstall.sh                  # Removes everything
├── nfc-check                     # PAM auth script → /usr/local/bin/
├── nfc-unlockd                   # Background daemon → ~/.local/bin/
├── nfc-unlockd.service           # systemd user service
├── nfc-auth.conf.example         # Config file format
├── 99-acr122u-nosuspend.rules    # udev rule (USB power)
├── pcscd-override.conf           # Keeps pcscd alive
└── README.md
```

## Adding more implants

Edit `/etc/nfc-auth.conf`:

```json
{
    "peter": ["04 11 22 33 44 55 66"],
    "alice": ["04 AA BB CC DD EE FF", "04 11 22 33 44 55 66"]
}
```

Restart the daemon: `systemctl --user restart nfc-unlockd`

## Uninstall

```bash
sudo ./uninstall.sh YOUR_USERNAME
```

Everything is removed: PAM config, systemd services, scripts, udev rules.
Password auth is restored to default.
