# NFC Implant Login

> **Author:** mazzarol  
> **Repository:** https://github.com/mazzarol/nfc-implant-login.git  
> **NFC Implants by:** https://dangerousthings.com  
> **License:** [GPL-3.0-or-later](LICENSE)  
> **Tested on:** Ubuntu 24.04.4 LTS (noble)

Walk up to your Linux desktop, tap your NFC implant, and you're in.
No password, no typing, no Enter key.

Note: If you need to press a key before scanning after screen blank, the xHCI USB
root hub is suspending. The included `98-xhci-nosuspend.rules` udev rule fixes this
by preventing root hubs from runtime-suspending — see **Power Considerations** below.


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

Note: The 04 prefix means "NXP Semiconductors" — the chips tested are NXP-made.


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
├── 98-xhci-nosuspend.rules      # udev rule (root hub power)
├── 99-acr122u-nosuspend.rules    # udev rule (device power)
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

## Power Considerations

The `98-xhci-nosuspend.rules` udev rule (installed by default) prevents the
USB root hub from entering runtime suspend. This is what lets the reader work
during screen blank without requiring a keypress first.

**Desktops and NUCs**: negligible impact — roughly 0.5–2 W extra at idle.
Leave it enabled.

**Laptops on battery**: the rule blocks package C-state entry, increasing idle
drain by roughly 5% to 10%. If battery life matters more than tap-to-unlock during
screen blank, remove the rule:

```bash
sudo rm /etc/udev/rules.d/98-xhci-nosuspend.rules
sudo udevadm control --reload-rules
```

The trade-off: you'll need to press a key to wake the bus before scanning after
the screen has been blank for a while. The daemon still unlocks instantly once
the bus is awake. A narrower fix (targeting only the specific bus number) is
possible but bus numbering is not stable across reboots, so it's not included.

**Security**: these udev rules only control USB power management. They do not
affect authentication, authorization, or reader access controls.

## Uninstall

```bash
sudo ./uninstall.sh YOUR_USERNAME
```

Everything is removed: PAM config, systemd services, scripts, udev rules.
Password auth is restored to default.
