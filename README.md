<p align="center">
  <img src="docs/img/wordmark.png" width="480" alt="Symbiote OS">
</p>

<p align="center">
  A Debian live distribution with a cinematic FUI desktop shell, built for
  security work and programming.<br>
  <sub>MIT OR GPL-3.0-or-later · Qt 6 / QML · Wayland</sub>
</p>

<p align="center">
  <a href="https://github.com/Ian-XG/symbiote-os/releases/latest"><b>Download the ISO</b></a>
</p>

![The desktop](docs/img/desktop.png)

Every number on that screen is measured. There is no placeholder data anywhere
in the interface: where a value cannot be read, the panel says so rather than
inventing one. The mass in the middle turns at the speed of the processor and
swells with memory in use, and the caption underneath says which — an
interface that encodes data without naming it is just a prettier kind of noise.

Free software, dual licensed under MIT or GPL-3.0-or-later at your option. The
desktop shell, the live-build configuration and the session scripts here are
all original work; the system underneath is Debian and the daemons the shell
talks to — NetworkManager, BlueZ, UPower, PipeWire — are theirs, not
reimplemented here.

**Dual-use.** The image ships penetration-testing tools. They are for systems
you own or have written permission to test. The software does not and cannot
know what you are authorised to touch.

The visual design originates in a Claude Design project (`../symbiote-os-design`);
this repository turns it into an operating system that boots.

## What it looks like

| | |
| --- | --- |
| ![Applications](docs/img/launcher.png) | ![Tools](docs/img/tools.png) |
| Applications: what the machine installed, read from its own desktop entries. | Tools: the security kit, grouped the way Kali groups its menu. |
| ![Settings](docs/img/settings.png) | ![Taskbar](docs/img/taskbar.png) |
| Ten sections down the side, and every control acts on something. | The bar goes on any edge. Bottom by default. |

![Signal blue](docs/img/signal.png)

The whole shell recolours from one property. Red stays reserved for states
that are genuinely critical.

### Applications and tools are different questions

A launcher that puts a text editor and a password cracker on the same
alphabetical wall makes both harder to find. **APPLICATIONS** is what you use;
**TOOLS** is what you point at a target, divided into RECON, VULNERABILITY,
WEB, DATABASE, PASSWORDS, WIRELESS, EXPLOITATION, SNIFFING, POST, REVERSING,
FORENSICS, ANONYMITY and DEFENSE — Kali's vocabulary, because that is the one
anyone doing this work already has. Search crosses both, since knowing the name
is the one case where categories are in the way.

Most of the security kit ships no desktop entry — nmap, sqlmap, hydra and
aircrack-ng are programs you type — so they are looked up on PATH and given a
terminal that stays open after the command exits. A tool the image does not
have is simply absent rather than advertised.

### The taskbar goes where you want it

Bottom, top, left or right, from Settings → Taskbar or by right-clicking the
desktop. Bottom is the default, because that is where a taskbar has been on
every system most people have used. On a 16:9 laptop panel the vertical pixels
are the scarce ones, and a bar down the side gives back seventy of them.

The bar is three zones — the mark and what is pinned, then the open windows,
then the tray. The window list takes whatever is left between the two fixed
ends and scrolls inside itself, so it can no longer be squeezed out by pinning
one more thing.

## Architecture

```
  greetd  ──autologin──▶  labwc (Wayland compositor)
                              │
                              ▼
                     Symbiote Shell (Qt 6 / QML)
                     ├── QtDBus ──▶ NetworkManager   (Wi-Fi)
                     │              BlueZ            (Bluetooth + pairing agent)
                     │              UPower           (battery)
                     │              logind           (shutdown / restart)
                     └── procfs ──▶ /proc, /sys      (CPU, RAM, thermal, processes)
```

**Wi-Fi and Bluetooth are not reimplemented.** Linux already has NetworkManager
and BlueZ. The shell is a *client* of those daemons over D-Bus, which is what
makes the project tractable at all.

`labwc` was chosen over `cage` once the shell needed to host other windows:
cage displays exactly one fullscreen surface, so a file manager or a browser
had nowhere to go.

### Why Qt instead of Electron

The first shell was Electron. It worked, and it cost 331 MB of RAM across two
processes and a full CPU core to animate one hologram. The Qt port does the
same job in a 3.8 MB binary at ~118 MB. The Electron tree is still in `shell/`
and will be removed once Qt has been proven on real hardware for a while.

## Layout

| Path | What |
| --- | --- |
| `shell-qt/` | The desktop shell: C++ services, QML interface |
| `distro/` | live-build configuration — packages, hooks, session scripts |
| `shell/` | The retired Electron shell, kept until the Qt one is trusted |
| `build.sh` | Runs inside the build container; produces the ISO |
| `Makefile` | Everything you actually invoke |
| `docs/img/` | The screenshots above, rendered headlessly by `make qt-shot` |

## Building

Requires Docker. live-build mounts loop devices and bind-mounts inside a
chroot, so the build container is `--privileged`; nothing persists from it but
the ISO.

```sh
make iso          # full ISO, ~25 min
make qt-check     # compile the shell and confirm the QML loads, ~3 min
make qt-shot      # render the shell headlessly to shot.png, ~3 min
make vm-run       # boot the ISO in VirtualBox
```

`make qt-shot` exists because looking at the design used to mean building an
ISO and booting a VM — 25 minutes to discover a hologram was invisible. It
renders the same scene graph offscreen in about three.

```sh
QTSCALE=2 SIZE=1440x900 make qt-shot   # as it looks on a HiDPI panel
OPEN=settings make qt-shot             # with a panel open
OPEN=settings:TASKBAR make qt-shot     # on a particular section
OPEN=launcher:tools make qt-shot       # in the tools drawer
OPEN=media make qt-shot                # volume and brightness
ACCENT=signal make qt-shot             # in the blue accent
```

## Running it

Ready-made images are on the [releases
page](https://github.com/Ian-XG/symbiote-os/releases). Verify what you
downloaded before writing it to anything:

```sh
shasum -a 256 -c SHA256SUMS
```

Flash the ISO to a USB stick (Balena Etcher works; the image is isohybrid).
User and password are both `symbiote` — the documented default of a live
image, as with any live distribution. Change it if the stick leaves your desk.

Kernel command line options, for when the defaults guess wrong:

| Option | Effect |
| --- | --- |
| `symbiote.gl=sw` | Force software rendering (blank screen on boot) |
| `symbiote.gl=hw` | Force hardware rendering |
| `symbiote.scale=2` | Force the interface scale |
| `symbiote.drm=card1` | Pick a specific GPU on a dual-GPU machine |
| `symbiote.shell=electron` | Boot the old Electron shell |

If the desktop does not appear, Ctrl+Alt+F2 gives a terminal. The logs are
`/tmp/symbiote-session.log` (which GPU was chosen, at what scale) and
`/tmp/symbiote-shell.log`.

## Persistence

A live image forgets everything on reboot. To keep settings and files, give it
a partition:

```sh
sudo symbiote-persist list
sudo symbiote-persist init /dev/sdX3          # or --luks to encrypt it
```

Settings state plainly whether persistence is active, because settings that
quietly evaporate are worse than settings that tell you they will.

## Security posture

- Inbound traffic is denied by default (`nftables`); outbound is unrestricted,
  since the toolset exists to reach out. Established connections come back in.
- AppArmor profiles are enabled.
- SSH is masked. There is no remote entry point.
- polkit grants the operator NetworkManager, BlueZ, udisks2 and shutdown —
  scoped to those, not a blanket yes. Without it the desktop could scan for
  Wi-Fi networks and never join one, because greetd starts the session through
  seatd rather than logind and polkit saw no active session.
- Autologin is on and the password is a published default. This is a live
  image for a laptop you carry, not a server.

## Known gaps

- APFS-formatted drives cannot be read. exFAT and NTFS work.
- Bluetooth on a Mac needs a Broadcom firmware blob that Debian cannot
  redistribute; a USB dongle works without it.
- Bluetooth audio needs `libspa-0.2-bluetooth` for PipeWire to offer a profile.
  Without it a headset pairs, connects and plays nothing — the panel says so
  rather than reporting a bare `br-connection-profile-unavailable`.
- Wi-Fi profiles live in `/etc/NetworkManager/system-connections`, which on a
  live boot is RAM. Networks joined are remembered for the session and lost on
  reboot unless there is a persistence partition. The panel states this rather
  than letting it look like a bug.

## Licence

`SPDX-License-Identifier: MIT OR GPL-3.0-or-later` — take it under either, at
your option. See [LICENSE](LICENSE) for what that covers and what it does not.

Worth knowing before you rely on the GPL half: when a work is offered under
*either* licence, a recipient can simply choose MIT. Dual licensing this way
does not keep derivatives open — it permits closed ones. That is a fine
choice; it is just not copyleft.
