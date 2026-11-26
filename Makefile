CACHE_DIR := cache
OUT_DIR   := out

ALARM_URL     := http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
ALARM_TARBALL := $(CACHE_DIR)/ArchLinuxARM-aarch64-latest.tar.gz
DISK_IMAGE    := $(CACHE_DIR)/disk.img
KERNEL        := $(CACHE_DIR)/Image
INITRD        := $(CACHE_DIR)/initramfs-linux.img

DISK_SIZE ?= 32G
VM_CPUS   ?= 4
VM_MEM    ?= 3G
# Mirror used while building, e.g. http://tw2.mirror.archlinuxarm.org (default: /etc/pacman.d/mirrorlist)
MIRROR    ?=

QEMU_ARGS := \
	-nographic \
	-machine virt \
	-cpu max \
	-smp $(VM_CPUS) \
	-m $(VM_MEM) \
	-netdev user,id=net0 \
	-device virtio-net-pci,netdev=net0 \
	-drive if=none,file=$(DISK_IMAGE),format=raw,id=hd0 \
	-device virtio-blk-pci,drive=hd0 \
	-virtfs local,path=$(CURDIR),mount_tag=host,security_model=none \
	-kernel $(KERNEL) \
	-initrd $(INITRD)

KERNEL_CMDLINE := root=/dev/vda rw rootfstype=ext4 console=ttyAMA0
MOUNT_HOST     := mkdir -p /mnt/host && mount -t 9p -o trans=virtio,version=9p2000.L,msize=1048576 host /mnt/host
# systemd.show_status=error hides the progress messages such as "A start job is running for ..."
# (printed while build.sh runs) so that the console shows only the build.sh log and errors
BUILD_CMDLINE  := $(KERNEL_CMDLINE) \
	systemd.show_status=error \
	systemd.run=\"/bin/sh -c '$(MOUNT_HOST) && exec /mnt/host/build.sh'\" \
	systemd.run_success_action=poweroff \
	systemd.run_failure_action=poweroff \
	$(if $(MIRROR),rootfs_builder.mirror=$(MIRROR))

.PHONY: build shell kernel clean distclean
build: kernel
	mkdir -p $(OUT_DIR)
	rm -f $(OUT_DIR)/.status
	qemu-system-aarch64 $(QEMU_ARGS) -append "$(BUILD_CMDLINE)"
	@test "$$(cat $(OUT_DIR)/.status 2>/dev/null)" = ok \
		|| { echo "Build failed; see $(OUT_DIR)/build.log" >&2; exit 1; }

# Boot the build VM without running build.sh (login: root / root).
# The project directory can be mounted with: $(MOUNT_HOST)
shell: kernel
	qemu-system-aarch64 $(QEMU_ARGS) -append "$(KERNEL_CMDLINE)"

# Always boot the kernel installed in the disk image so that it matches its modules
kernel: $(DISK_IMAGE)
	debugfs -R "dump /boot/Image $(KERNEL)" $(DISK_IMAGE)
	debugfs -R "dump /boot/initramfs-linux.img $(INITRD)" $(DISK_IMAGE)

$(DISK_IMAGE): $(ALARM_TARBALL)
	mkfs.ext4 -q -F -d $< $@.tmp $(DISK_SIZE)
	mv -f $@.tmp $@

$(ALARM_TARBALL):
	mkdir -p $(CACHE_DIR)
	curl -fL --progress-bar -o $@.tmp $(ALARM_URL)
	curl -fL $(ALARM_URL).md5 | sed 's|[^ ]*$$|$@.tmp|' | md5sum -c
	mv -f $@.tmp $@

clean:
	rm -rf $(OUT_DIR)

distclean: clean
	rm -rf $(CACHE_DIR)
