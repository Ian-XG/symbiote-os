#!/usr/bin/env bash
# Drive the live image in VirtualBox and read real text back out of it.
#
# Screenshots plus OCR was the previous way, and it was slow and it lied: a
# wrapped line or a thin glyph came back as a plausible wrong answer. The guest
# writes to a serial port that VirtualBox spools into a file on the host, so
# what arrives here is the command's actual stdout.
#
# This is how the missing SVG plugin, the 25-second Bluetooth stall at startup
# and the second desktop painted over the first were all found. It lives in the
# repository rather than in a scratch directory because it kept being deleted
# and rewritten from memory.
#
#   tools/vm-probe.sh boot          boot headless and wait for the desktop
#   tools/vm-probe.sh term          open a terminal via the shell's Ctrl+Alt+T
#   tools/vm-probe.sh run <file>    type <file> into it, capture the output
#   tools/vm-probe.sh type <text>   type one line and press return
#   tools/vm-probe.sh shot <name>   screenshot the whole screen
#   tools/vm-probe.sh off           power off
#
# Run `make vm-attach` first after every build, or it boots the previous image.
set -uo pipefail

VM="${SYMBIOTE_VM:-Symbiote OS}"
OUT="${SYMBIOTE_PROBE_DIR:-${TMPDIR:-/tmp}/symbiote-probe}"
mkdir -p "$OUT"
SERIAL="$OUT/serial.log"

case "${1:-}" in
boot)
  state=$(VBoxManage showvminfo "$VM" --machinereadable 2>/dev/null \
          | sed -n 's/^VMState="\(.*\)"$/\1/p')
  case "$state" in
    running|paused) "$0" off ;;
    saved|aborted-saved)
      # A suspended VM refuses every modifyvm below with "the machine is not
      # mutable", and restoring the snapshot then fails anyway because the
      # attached ISO has been replaced underneath it. Throw the state away.
      VBoxManage discardstate "$VM" >/dev/null 2>&1; sleep 1 ;;
  esac
  # uartmode "file" appends; truncating keeps one run per file.
  : > "$SERIAL"
  VBoxManage modifyvm "$VM" --uart1 0x3F8 4 --uartmode1 file "$SERIAL"
  VBoxManage startvm "$VM" --type headless >/dev/null || exit 1
  # Measured booting from the ISO; booting from a virtual disk that is still
  # allocating blocks is slower, so this is the slow case with room to spare.
  sleep 140
  echo booted
  ;;

term)
  # Ctrl+Alt+T, the shell's own shortcut. greetd runs without logind so the
  # compositor never hands over the VT and Ctrl+Alt+F2 does nothing; going in
  # through the shell also means a failure here is a bug worth knowing about.
  #
  # Sent three times, spaced out. A single chord is silently dropped when the
  # shell has drawn but its QML shortcuts are not live yet, which happens on a
  # slower boot -- from a dynamically-allocated virtual disk rather than the
  # CD, for instance. That cost three runs that looked like the probe hanging.
  # Extra terminals are harmless; the newest one has focus, which is the one
  # `run` types into.
  for _ in 1 2 3; do
    VBoxManage controlvm "$VM" keyboardputscancode 1d 38 14 94 b8 9d
    sleep 5
  done
  echo terminal
  ;;

type)
  VBoxManage controlvm "$VM" keyboardputstring "$2"
  VBoxManage controlvm "$VM" keyboardputscancode 1c 9c
  ;;

run)
  mark="PROBE$$"
  before=$(wc -c < "$SERIAL")
  # Planted with a quoted here-doc rather than pasted as one command line: sent
  # inline, the first grep pattern containing a pipe closed the quoting and ran
  # half the script as commands.
  VBoxManage controlvm "$VM" keyboardputstring "cat > /tmp/probe.sh <<'SYMEOF'"
  VBoxManage controlvm "$VM" keyboardputscancode 1c 9c; sleep 1
  VBoxManage controlvm "$VM" keyboardputfile "$2"; sleep 2
  VBoxManage controlvm "$VM" keyboardputstring "SYMEOF"
  VBoxManage controlvm "$VM" keyboardputscancode 1c 9c; sleep 1
  # tee, not "> /dev/ttyS0": the redirect is performed by the calling shell,
  # which is the unprivileged user, so sudo never got a chance to help.
  VBoxManage controlvm "$VM" keyboardputstring \
    "{ echo ${mark}S; sudo sh /tmp/probe.sh 2>&1; echo ${mark}E; } | sudo tee /dev/ttyS0 >/dev/null"
  VBoxManage controlvm "$VM" keyboardputscancode 1c 9c
  for _ in $(seq 1 40); do
    sleep 3; grep -q "${mark}E" "$SERIAL" 2>/dev/null && break
  done
  tail -c "+$((before + 1))" "$SERIAL" | tr -d '\r' \
    | sed -n "/${mark}S/,/${mark}E/p" | grep -v "$mark"
  ;;

push)
  # Hand a file to the guest on a tiny ISO, mounted as a second optical drive.
  #
  # `run` types its payload through the virtual keyboard, which is fine for a
  # twenty-line probe and hopeless for anything bigger: planting a 7 KB script
  # left the guest still echoing here-doc lines after two minutes. There is no
  # shared folder without guest additions and no server to curl from, but an
  # ISO is just a file, and attaching one is instant.
  src="$2"
  stage=$(mktemp -d)
  cp "$src" "$stage/payload"
  iso="$OUT/payload.iso"
  rm -f "$iso"
  hdiutil makehybrid -quiet -iso -joliet -o "$iso" "$stage" >/dev/null 2>&1 \
    || { echo "could not build the payload ISO" >&2; exit 1; }
  rm -rf "$stage"
  # Port 1 on the same controller: port 0 holds the image being tested.
  VBoxManage storageattach "$VM" --storagectl IDE --port 1 --device 0 \
    --type dvddrive --medium "$iso" 2>/dev/null \
    || VBoxManage storageattach "$VM" --storagectl IDE --port 1 --device 0 \
         --type dvddrive --medium "$iso"
  echo "$iso"
  ;;

shot)
  VBoxManage controlvm "$VM" screenshotpng "$OUT/${2:-shot}.png" >/dev/null 2>&1 \
    && echo "$OUT/${2:-shot}.png"
  ;;

off)
  # Clean shutdown, not a yanked cable.
  #
  # `poweroff` cuts power instantly. Testing persistence that way produced
  # files that survived a reboot at zero length: ext4's default journalling
  # keeps the metadata and loses data blocks that were never flushed, so the
  # files existed and were empty, which reads exactly like a broken feature.
  # It was the harness. The ACPI button lets the guest sync and unmount.
  VBoxManage controlvm "$VM" acpipowerbutton >/dev/null 2>&1
  for _ in $(seq 1 30); do
    VBoxManage showvminfo "$VM" --machinereadable 2>/dev/null \
      | grep -q 'VMState="poweroff"' && { echo off; exit 0; }
    sleep 2
  done
  # It ignored the button, or has no session left to handle it.
  VBoxManage controlvm "$VM" poweroff >/dev/null 2>&1
  echo "off (forzado)"
  ;;
*) sed -n '15,21p' "$0"; exit 2 ;;
esac
