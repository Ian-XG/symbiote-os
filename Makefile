IMAGE  := symbiote-build
ISO    := distro/live-image-amd64.hybrid.iso
VM     := Symbiote OS

# Handy copy outside the repo. It is refreshed by `make iso` on purpose: a
# stale copy sitting somewhere convenient is worse than no copy, because you
# test the wrong image and debug a problem that was already fixed.
HANDY  := $(HOME)/Documents/SymbioteOS.iso

.PHONY: help image iso shell-check qt-check qt-shot clean clean-cache vm-create vm-attach vm-run

help:
	@echo "make image       build the Docker build-host image"
	@echo "make iso         build the Symbiote OS ISO (needs Docker running)"
	@echo "make shell-check syntax-check the Electron shell (runs on macOS)"
	@echo "make qt-check    compile only the Qt shell (~3 min, no ISO)"
	@echo "make qt-shot     render the shell offscreen to shot.png (~3 min, no ISO)"
	@echo "make vm-create   create or reconfigure the VirtualBox VM"
	@echo "make vm-attach   point the VM at the newest ISO (run after make iso)"
	@echo "make vm-run      boot the ISO in VirtualBox"
	@echo "make clean       remove build artefacts"
	@echo "make clean-cache drop cached Debian/npm downloads (forces a full re-fetch)"

image:
	docker build -f Dockerfile.build -t $(IMAGE) .

# live-build mounts loop devices and bind-mounts inside a chroot, so this needs
# --privileged. It is a throwaway container; nothing persists but the ISO.
iso: image
	docker volume create symbiote-work >/dev/null
	docker run --rm --privileged \
		-v "$(PWD)":/build \
		-v symbiote-work:/work \
		-w /build \
		$(IMAGE) ./build.sh
	@cp "$(PWD)/$(ISO)" "$(HANDY)"
	@echo "refreshed $(HANDY)"
	@shasum -a 256 "$(HANDY)" | cut -c1-16 | sed 's/^/sha256: /'

# Drop the cached Debian packages and npm/electron downloads.
clean-cache:
	-docker volume rm symbiote-work

# Compile just the Qt shell. A full `make iso` is ~25 minutes; this is ~3, so
# a compile error costs one coffee rather than one afternoon.
#
# `-e` is not decoration. Without it a failed compile still ran to the end of
# the script and printed "QT SHELL OK" with an empty size, which is the worst
# possible outcome: a check that reports success for a build that did not
# happen.
qt-check: image
	docker run --rm -v "$(PWD)":/build -v symbiote-work:/work -w /build \
		$(IMAGE) bash -euo pipefail -c '\
			rm -rf /work/qtcheck && mkdir -p /work/qtcheck && \
			rsync -a --exclude build /build/shell-qt/ /work/qtcheck/src/ && \
			cmake -S /work/qtcheck/src -B /work/qtcheck/build -G Ninja \
				-DCMAKE_BUILD_TYPE=Release && \
			cmake --build /work/qtcheck/build && \
			echo "--- compiled; now checking the QML actually resolves ---" && \
			{ QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
			  timeout 12 /work/qtcheck/build/symbiote-shell-qt > /tmp/qtrun.log 2>&1 || true; }; \
			cat /tmp/qtrun.log; \
			if grep -qE "failed to load|no type named|is not a type|Cannot assign|ReferenceError" /tmp/qtrun.log; then \
				echo "QT SHELL: QML DID NOT LOAD"; exit 1; \
			fi; \
			echo "QT SHELL OK: $$(du -h /work/qtcheck/build/symbiote-shell-qt | cut -f1)"'

# SIZE/OPEN/DELAY are make variables, expanded here on the host: the
# container's shell never sees the caller's environment, so $${OPEN} inside
# the quoted command silently expanded to nothing.
# Render the shell headlessly and copy the PNG out. Looking at the design used
# to mean building an ISO and booting a VM: 25 minutes to find out a hologram
# was invisible. This is the same scene graph, in about three.
qt-shot: image
	@rm -f "$(PWD)/shot.png"   # a stale PNG would let `test -f` below report success
	docker run --rm -v "$(PWD)":/build -v symbiote-work:/work -w /build \
		$(IMAGE) bash -c '\
			rm -rf /work/qtshot && mkdir -p /work/qtshot && \
			rsync -a --exclude build /build/shell-qt/ /work/qtshot/src/ && \
			cmake -S /work/qtshot/src -B /work/qtshot/build -G Ninja \
				-DCMAKE_BUILD_TYPE=Release >/dev/null && \
			cmake --build /work/qtshot/build >/dev/null && \
			QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
			SYMBIOTE_SCALE=1 QT_SCALE_FACTOR=$(or $(QTSCALE),1) SYMBIOTE_SHOT=/build/shot.png \
			SYMBIOTE_SHOT_SIZE=$(or $(SIZE),1920x1080) SYMBIOTE_OPEN=$(OPEN) SYMBIOTE_ACCENT=$(ACCENT) \
			SYMBIOTE_SHOT_DELAY=$(or $(DELAY),2500) \
			timeout 40 /work/qtshot/build/symbiote-shell-qt 2>&1 | tail -20; \
			test -f /build/shot.png || { echo "NO SHOT WRITTEN"; exit 1; }'
	@echo "wrote $(PWD)/shot.png"

# Runs on the Mac directly — no container, no Linux needed.
shell-check:
	cd shell && node --check src/main/main.js \
		&& node --check src/main/preload.js \
		&& node --check src/main/bridge/index.js \
		&& node --check src/main/bridge/system.js \
		&& node --check src/main/bridge/network.js \
		&& node --check src/main/bridge/bluetooth.js \
		&& node --check src/main/bridge/power.js \
		&& echo "shell: syntax OK"

# Idempotent: creates the VM only if it does not already exist, then always
# (re)attaches the current ISO. A VM whose optical drive is empty boots to
# "No bootable medium found", which looks like an ISO problem but is not.
vm-create:
	@VBoxManage list vms | grep -q '"$(VM)"' || ( \
		VBoxManage createvm --name "$(VM)" --ostype Debian_64 --register && \
		VBoxManage storagectl "$(VM)" --name IDE --add ide )
	VBoxManage modifyvm "$(VM)" --memory 4096 --cpus 2 --vram 256 \
		--graphicscontroller vmsvga --accelerate3d on \
		--nic1 nat --audio-driver none \
		--boot1 dvd --boot2 disk --boot3 none --boot4 none
	$(MAKE) vm-attach

# Point the VM's optical drive at the ISO built most recently. Run this after
# every `make iso` or the VM keeps booting the previous image.
vm-attach:
	VBoxManage storageattach "$(VM)" --storagectl IDE --port 0 --device 0 \
		--type dvddrive --medium "$(PWD)/$(ISO)"
	@echo "attached: $(PWD)/$(ISO)"

vm-run:
	VBoxManage startvm "$(VM)"

clean:
	rm -rf shell/dist shell/node_modules
	rm -rf distro/.build distro/chroot distro/binary distro/cache
	rm -f distro/*.iso distro/*.contents distro/*.files distro/*.packages
