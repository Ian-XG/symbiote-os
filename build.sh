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
rm -rf "$WORK/shell" "$WORK/shell-qt" "$WORK/build-qt" "$WORK/distro"

export npm_config_cache="$WORK/.npm"
export electron_config_cache="$WORK/.electron"
# node_modules and dist are host-built (macOS binaries) and must not come along.
rsync -a --exclude node_modules --exclude dist "$SRC/shell/" "$WORK/shell/"
rsync -a --exclude build "$SRC/shell-qt/" "$WORK/shell-qt/"
rsync -a --exclude '.build' --exclude chroot --exclude binary --exclude cache \
	--exclude '*.iso' "$SRC/distro/" "$WORK/distro/"

if [ -d "$CACHE_KEEP" ]; then
	mv "$CACHE_KEEP" "$WORK/distro/cache"
	echo "I: restored $(du -sh "$WORK/distro/cache" | cut -f1) of cached packages"
fi
df -h "$WORK" | tail -1

step "Building the Electron shell"
cd "$WORK/shell"
if [ -f package-lock.json ]; then
	npm ci --foreground-scripts
else
	echo "W: no package-lock.json, falling back to npm install"
	npm install --foreground-scripts
fi

# electron's postinstall fetches the platform binary. Newer npm can gate install
# scripts, and a silently skipped download breaks electron-builder much later
# with a confusing error — so check for it here.
if [ ! -d node_modules/electron/dist ]; then
	echo "I: electron binary missing, running its install script explicitly"
	( cd node_modules/electron && node install.js )
fi

# Same gate applies to esbuild, which also fetches a platform binary on install.
if ! node -e "require('esbuild')" >/dev/null 2>&1; then
	echo "I: esbuild binary missing, running its install script explicitly"
	( cd node_modules/esbuild && node install.js )
fi

npm run check                       # syntax gate before we spend 20 minutes on an ISO

step "Compiling the HUD for offline use"
# The design kit loads React/Babel/Lucide from a CDN and compiles JSX in the
# browser. The shell blocks all network access, so this precompiles the JSX and
# vendors the libraries locally.
npm run bundle
test -f src/renderer/build/kit.js || { echo "E: renderer bundle missing" >&2; exit 1; }

npx electron-builder --linux dir

step "Staging the shell into the image"
STAGE="$WORK/distro/config/includes.chroot/opt/symbiote/shell"
rm -rf "$STAGE"
mkdir -p "$STAGE"
rsync -a "$WORK/shell/dist/linux-unpacked/" "$STAGE/"
# electron-builder names the binary after productName ("Symbiote Shell").
if [ -f "$STAGE/Symbiote Shell" ]; then
	mv "$STAGE/Symbiote Shell" "$STAGE/symbiote-shell"
fi
if [ ! -f "$STAGE/symbiote-shell" ]; then
	echo "E: shell binary not found after packaging; contents were:" >&2
	ls -la "$STAGE" >&2
	exit 1
fi
chmod +x "$STAGE/symbiote-shell"

step "Building the Qt shell"
# Built alongside the Electron one, not instead of it: until the Qt shell has
# proven itself on real hardware, the image keeps a session that is known to
# start. symbiote-session picks between them.
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
