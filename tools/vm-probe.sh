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
  VBoxManage showvminfo "$VM" --machinereadable 2>/dev/null | grep -q 'VMState="running"' \
    && { VBoxManage controlvm "$VM" poweroff >/dev/null 2>&1; sleep 3; }
  # uartmode "file" appends; truncating keeps one run per file.
  : > "$SERIAL"
  VBoxManage modifyvm "$VM" --uart1 0x3F8 4 --uartmode1 file "$SERIAL"
  VBoxManage startvm "$VM" --type headless >/dev/null || exit 1
  sleep 100          # measured on this image, not guessed
  echo booted
  ;;

term)
  # Ctrl+Alt+T, the shell's own shortcut. greetd runs without logind so the
  # compositor never hands over the VT and Ctrl+Alt+F2 does nothing; going in
  # through the shell also means a failure here is a bug worth knowing about.
  VBoxManage controlvm "$VM" keyboardputscancode 1d 38 14 94 b8 9d
  sleep 6; echo terminal
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

shot)
  VBoxManage controlvm "$VM" screenshotpng "$OUT/${2:-shot}.png" >/dev/null 2>&1 \
    && echo "$OUT/${2:-shot}.png"
  ;;

off) VBoxManage controlvm "$VM" poweroff >/dev/null 2>&1; echo off ;;
*) sed -n '15,21p' "$0"; exit 2 ;;
esac
