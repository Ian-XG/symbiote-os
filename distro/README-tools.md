# Security tools: what is in the image, and what is not

The image ships the security tools that Debian trixie packages in `main` and
`non-free-firmware`. That is most of the everyday kit — scanners, crackers,
sniffers, the wireless suite — and it installs with no third-party archive and
no vendor blob, which is the whole reason to prefer it.

Some tools people expect from Kali are **not in Debian at all**. They are left
out of the package lists rather than named, because live-build hands every line
to `apt` verbatim and one unknown name fails the build a long way from the line
that caused it. `.github/workflows/packages.yml` resolves every list against the
real trixie archive on each change, so a name that has been renamed or removed
is caught in a minute instead of twenty.

## Not packaged by Debian — install by hand

These want either the Kali archive, a language package manager, or a `git
clone`. None is hard; none is something the image can ship cleanly.

| Tool | How to get it |
| --- | --- |
| **Metasploit** | Rapid7's installer, or the Kali repo. Not redistributable in Debian. |
| **Burp Suite** | PortSwigger's installer (the Community edition is free). |
| **nikto** | `git clone https://github.com/sullo/nikto` — a Perl script, removed from Debian. |
| **theHarvester** | `pipx install theHarvester`. |
| **Responder** | `git clone https://github.com/lgandx/Responder`. |
| **CrackMapExec / NetExec** | `pipx install netexec` (NetExec is the maintained fork). |
| **SecLists** | `git clone https://github.com/danielmiessler/SecLists` — wordlists, not a program. |

## Removed or renamed in trixie

These were named in the original package lists and have since disappeared from
the archive as trixie froze. The build was updated to match — coverage is kept
where another package provides the same files.

| Was | Now |
| --- | --- |
| `firmware-intel-graphics` | folded into `firmware-misc-nonfree` |
| `firmware-brcm80211` | pulled in by the `firmware-linux` metapackage |
| `bluez-firmware` | adapter firmware now comes from the `firmware-*` packages |
| `nikto` | removed from Debian (see above) |

## The two assistants

Neither is a Debian package; both are installed by a hook under
`distro/config/hooks/normal/`, and both need network **at build time** to fetch
their source. A build with no network leaves them out with a warning rather than
shipping a launcher entry that fails when clicked.

- **PentAI** — `0500-pentai.hook.chroot` clones it into a virtualenv at
  `/opt/pentai`.
- **Ollama** — `0600-ollama.hook.chroot` installs the upstream binary and
  prunes its CUDA/ROCm runners (~1.3 GB of GPU blobs). No model is shipped;
  `ollama-setup` pulls one on first run, stating the sizes first. Without a
  persistence partition a pulled model lives in RAM and is gone on reboot.
