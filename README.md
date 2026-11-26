# rootfs-builder

Builds the AArch64 Arch Linux ARM rootfs (`.tar.zst`) used by yabe's Andlify environment.

`make` does everything without root privileges:

1. Downloads `ArchLinuxARM-aarch64-latest.tar.gz` into `cache/` (verified with its `.md5`).
2. Creates `cache/disk.img` from the tarball with `mkfs.ext4 -d` (requires e2fsprogs 1.47.1 or later).
3. Boots it with `qemu-system-aarch64`, sharing this directory over virtio-9p, and runs `build.sh` via `systemd.run=`.
4. `build.sh` copies `profile/airootfs`, installs `profile/packages` with `pacstrap`, installs `yay` and the packages in `profile/packages.aur` inside the rootfs, cleans it up, and writes `out/<image_name>-<date>-aarch64.tar.zst`.
5. The VM powers off. `make` fails if the build failed; see `out/build.log`.

`cache/disk.img` is reused between builds, so the pacman package cache survives. Run `make distclean` to start over.

## Requirements

`qemu-system-aarch64` (with virtio-9p), `e2fsprogs` (>= 1.47.1), `curl`

## Profile

| Path                   | Description                                                                     |
| ---------------------- | ------------------------------------------------------------------------------- |
| `profile/config.sh`    | `image_name` and `file_permissions` (same format as archiso's `profiledef.sh`)  |
| `profile/packages`     | Packages from the official repositories                                          |
| `profile/packages.aur` | AUR packages; dependencies on other AUR packages are resolved by `yay`          |
| `profile/pacman.conf`  | pacman configuration used by `pacstrap`                                          |
| `profile/airootfs/`    | Files copied into the rootfs before installing packages                         |

`yay` is always built from the AUR and installed in the rootfs, even if `profile/packages.aur` is empty.
PKGBUILDs that do not list `aarch64` are built anyway (yay's default with `--noconfirm`); packages that ship prebuilt x86_64 binaries do not work.

## Variables

| Variable    | Default | Description              |
| ----------- | ------- | ------------------------ |
| `DISK_SIZE` | `32G`   | Size of `cache/disk.img` (only used on creation) |
| `VM_CPUS`   | `4`     | Number of VM CPUs        |
| `VM_MEM`    | `3G`    | VM memory                |
| `MIRROR`    | (empty) | Mirror used only while building, e.g. `http://tw2.mirror.archlinuxarm.org`. The image keeps `profile/airootfs/etc/pacman.d/mirrorlist` |

## Debugging

`make shell` boots the same VM without running `build.sh` (login: `root` / `root`).

## LICENSE

Dual-licensed; MIT (`LICENSE-MIT` or [The MIT License – Open Source Initiative](https://opensource.org/license/mit/)) or MIT SUSHI-WARE LICENSE (`LICENSE-MIT_SUSHI.md`)
