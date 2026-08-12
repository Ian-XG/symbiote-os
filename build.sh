#!/usr/bin/env bash
# Builds the Symbiote OS ISO. Runs INSIDE the build container (see Makefile).
set -euo pipefail

SRC="${SYMBIOTE_SRC:-/build}"   # bind mount from the host: source in, ISO out
WORK="${SYMBIOTE_WORK:-/work}"  # container-local filesystem: everything else

step() { printf '\n\033[1;32m==>\033[0m %s\n' "$1"; }

# Why we copy instead of building in place:
# on macOS the repo reaches the container through virtiofs, which does not
# provide the POSIX semantics this build needs — npm ci cannot rmdir a populated
# node_modules, and debootstrap cannot create device nodes or set ownership
# inside the chroot. Both fail in confusing ways. So the build happens on the
# container's own overlay filesystem and only the finished ISO is copied back.
if [ ! -d "$SRC" ]; then
	echo "E: $SRC not found — this script runs inside the build container (use 'make iso')" >&2
	exit 1
fi

# A build killed part-way leaves $WORK/distro/chroot behind with live bind
# mounts inside it, and the next run dies on "Directory not empty" without
# saying why. Detach and clear before anything else touches it.
for m in $(awk '{print $2}' /proc/mounts | grep "^$WORK/distro/" | sort -r); do
	umount -lf "$m" 2>/dev/null || true
done

step "Copying source into the container filesystem"
mkdir -p "$WORK"

# /work is a named docker volume, so package downloads survive between runs.
# Without this every iteration re-fetches the whole Debian base — about 10
# minutes of pure download before it can even reach the part that failed.
CACHE_KEEP="$WORK/.cache-keep"
if [ -d "$WORK/distro/cache" ]; then
	echo "I: preserving live-build package cache"
	rm -rf "$CACHE_KEEP"
	mv "$WORK/distro/cache" "$CACHE_KEEP"
fi
rm -rf "$WORK/shell-qt" "$WORK/build-qt" "$WORK/distro"

# node_modules and dist are host-built (macOS binaries) and must not come along.
rsync -a --exclude build "$SRC/shell-qt/" "$WORK/shell-qt/"
rsync -a --exclude '.build' --exclude chroot --exclude binary --exclude cache \
	--exclude '*.iso' "$SRC/distro/" "$WORK/distro/"

if [ -d "$CACHE_KEEP" ]; then
	mv "$CACHE_KEEP" "$WORK/distro/cache"
	echo "I: restored $(du -sh "$WORK/distro/cache" | cut -f1) of cached packages"
fi
df -h "$WORK" | tail -1

# The Electron shell is no longer built.
#
# It was kept as a fallback while the Qt port proved itself, and it has now
# been proven — on the reporter's own laptop, with real windows, a real radio
# and a real battery. Keeping it cost more than it was worth:
#
#   - electron-builder downloads the Electron binary from GitHub on every
#     build, so an image with no network dependency of its own could not be
#     built without one. That is what finally broke: a failed download, in a
#     component nothing runs.
#   - It was most of the build's wall-clock time and a couple of hundred
#     megabytes of an image already close to the 2 GB single-file limit.
#   - It was the thing being measured when the desktop was found holding a
#     whole CPU core at idle.
#
# The source stays in shell/ rather than being deleted: it is the reference for
# what the Qt port had to reproduce, and it costs nothing in the image. If it
# is ever wanted again, this is the step that built it — see the git history.

step "Building the Qt shell"
# The only shell in the image.
cmake -S "$WORK/shell-qt" -B "$WORK/build-qt" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$WORK/build-qt"

QT_STAGE="$WORK/distro/config/includes.chroot/opt/symbiote/shell-qt"
rm -rf "$QT_STAGE"
mkdir -p "$QT_STAGE"
cp "$WORK/build-qt/symbiote-shell-qt" "$QT_STAGE/"
chmod +x "$QT_STAGE/symbiote-shell-qt"
echo "I: qt shell $(du -h "$QT_STAGE/symbiote-shell-qt" | cut -f1)"

step "Configuring live-build"
cd "$WORK/distro"
chmod +x auto/config
./auto/config

step "Building the ISO (this is the long part)"
lb build

step "Copying the ISO back to the host"
mkdir -p "$SRC/distro"
ISO="$(find "$WORK/distro" -maxdepth 1 -name '*.iso' -print -quit)"
if [ -z "$ISO" ]; then
	echo "E: live-build produced no ISO" >&2
	exit 1
fi
cp "$ISO" "$SRC/distro/"
ls -lh "$SRC/distro/$(basename "$ISO")"

step "Done"
