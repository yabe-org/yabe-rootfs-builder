#!/bin/bash
# Runs as root inside the Arch Linux ARM build VM started by `make`.
# The project directory is mounted at the directory containing this script.
set -euo pipefail

host_dir="$(dirname "$(realpath "$0")")"
profile="${host_dir}/profile"
out_dir="${host_dir}/out"
status_file="${out_dir}/.status"
work_dir="/var/tmp/rootfs-build"
root="${work_dir}/root"
aur_user="aurbuilder"
# Set by `make MIRROR=...`; used only while building and not written to the image
mirror="$(sed -n 's/.*rootfs_builder\.mirror=\([^ ]*\).*/\1/p' /proc/cmdline)"
mirrorlist="/run/rootfs-builder-mirrorlist"

on_exit() {
  local rc=$?
  # Flush the log before the VM powers off
  exec >&- 2>&-
  wait "${tee_pid}" || true
  if (( rc == 0 )); then
    echo ok >"${status_file}"
  else
    echo failed >"${status_file}"
  fi
}

mkdir -p "${out_dir}"
echo running >"${status_file}"
exec > >(tee "${out_dir}/build.log" >/dev/console) 2>&1
tee_pid=$!
trap on_exit EXIT

msg() { printf '==> %s\n' "$*"; }

# Print a package list without comments and blank lines
read_list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; }

# mirror.archlinuxarm.org sometimes stalls, so retry commands that download packages
retry() {
  local i
  for i in 1 2 3; do
    "$@" && return 0
    echo "Command failed (attempt ${i}/3): $*" >&2
    sleep 10
  done
  return 1
}

setup_vm() {
  msg "Starting network..."
  systemctl start systemd-networkd systemd-resolved
  /usr/lib/systemd/systemd-networkd-wait-online --timeout=120

  if [[ -n "${mirror}" ]]; then
    msg "Using mirror ${mirror}"
    # shellcheck disable=SC2016
    printf 'Server = %s/$arch/$repo\n' "${mirror}" >"${mirrorlist}"
    mount --bind "${mirrorlist}" /etc/pacman.d/mirrorlist
  fi

  msg "Preparing build environment..."
  if ! pacman-key --list-keys &>/dev/null; then
    pacman-key --init
  fi
  pacman-key --populate archlinuxarm
  retry pacman -Sy --needed --noconfirm archlinuxarm-keyring
  retry pacman -Su --needed --noconfirm arch-install-scripts libarchive zstd
}

copy_airootfs() {
  local filename permissions
  msg "Copying airootfs..."
  install -d -m 0755 -o 0 -g 0 -- "${root}"
  [[ -d "${profile}/airootfs" ]] || return 0
  cp -af --no-preserve=ownership,mode -- "${profile}/airootfs/." "${root}"
  # .gitkeep only lets git track otherwise empty directories
  find "${root}" -xdev -type f -name .gitkeep -delete
  for filename in "${!file_permissions[@]}"; do
    IFS=':' read -ra permissions <<<"${file_permissions["${filename}"]}"
    if [[ "$(realpath -q -- "${root}${filename}")" != "${root}"* ]]; then
      echo "Failed to set permissions on '${filename}': outside of rootfs" >&2
      return 1
    elif [[ ! -e "${root}${filename}" ]]; then
      echo "Warning: cannot change permissions of '${filename}': not found" >&2
    elif [[ "${filename: -1}" == "/" ]]; then
      chown -fhR -- "${permissions[0]}:${permissions[1]}" "${root}${filename}"
      chmod -fR -- "${permissions[2]}" "${root}${filename}"
    else
      chown -fh -- "${permissions[0]}:${permissions[1]}" "${root}${filename}"
      chmod -f -- "${permissions[2]}" "${root}${filename}"
    fi
  done
}

install_packages() {
  local -a pkgs
  mapfile -t pkgs < <(read_list "${profile}/packages")
  msg "Installing packages..."
  retry env -u TMPDIR pacstrap -C "${profile}/pacman.conf" -c -G -M -- "${root}" "${pkgs[@]}"
}

# Always installs yay, then installs the AUR packages listed in the profile with it
install_aur_packages() {
  local -a pkgs
  local yay_install=""
  mapfile -t pkgs < <(read_list "${profile}/packages.aur")
  if (( ${#pkgs[@]} > 0 )); then
    yay_install="sudo -u ${aur_user} -H yay -S --needed --noconfirm --removemake \\
  --answerclean None --answerdiff None --answeredit None -- ${pkgs[*]}"
  fi

  msg "Installing yay and AUR packages: ${pkgs[*]:-(none)}"
  # Not under /tmp because arch-chroot mounts a tmpfs there
  install -m 0755 /dev/stdin "${root}/var/tmp/install-aur.sh" <<EOF
#!/bin/bash
set -euo pipefail
# The keyring is only needed while installing; it is removed afterwards so that
# the image does not ship a pre-generated master key (same as pacstrap -G).
pacman-key --init
pacman-key --populate archlinuxarm
pacman -S --needed --noconfirm base-devel git sudo
useradd -r -m -d /var/tmp/${aur_user} ${aur_user}
echo '${aur_user} ALL=(ALL:ALL) NOPASSWD: ALL' >/etc/sudoers.d/${aur_user}
chmod 0440 /etc/sudoers.d/${aur_user}
sudo -u ${aur_user} -H bash -c '
  set -euo pipefail
  cd ~
  git clone --depth 1 https://aur.archlinux.org/yay.git
  cd yay
  makepkg -sir --noconfirm
'
${yay_install}
rm -f /etc/sudoers.d/${aur_user}
# Background processes such as gpg-agent may outlive the build
pkill -KILL -u ${aur_user} || true
while pgrep -u ${aur_user} >/dev/null; do sleep 1; done
userdel -r ${aur_user}
rm -f /etc/passwd- /etc/group- /etc/shadow- /etc/gshadow-
gpgconf --homedir /etc/pacman.d/gnupg --kill all
rm -rf /etc/pacman.d/gnupg
EOF
  # pacman's CheckSpace fails unless the chroot's / is a mount point
  mount --bind "${root}" "${root}"
  [[ -z "${mirror}" ]] || mount --bind "${mirrorlist}" "${root}/etc/pacman.d/mirrorlist"
  env -u TMPDIR arch-chroot "${root}" /var/tmp/install-aur.sh
  [[ -z "${mirror}" ]] || umount "${root}/etc/pacman.d/mirrorlist"
  umount "${root}"
}

# Same as mkarchiso's _cleanup_pacstrap_dir
cleanup_rootfs() {
  msg "Cleaning up rootfs..."
  [[ -d "${root}/boot" ]] && find "${root}/boot" -mindepth 1 -delete
  [[ -d "${root}/var/lib/pacman" ]] && find "${root}/var/lib/pacman" -maxdepth 1 -type f -delete
  [[ -d "${root}/var/lib/pacman/sync" ]] && find "${root}/var/lib/pacman/sync" -delete
  [[ -d "${root}/var/cache/pacman/pkg" ]] && find "${root}/var/cache/pacman/pkg" -type f -delete
  [[ -d "${root}/var/log" ]] && find "${root}/var/log" -type f -delete
  [[ -d "${root}/var/tmp" ]] && find "${root}/var/tmp" -mindepth 1 -delete
  find "${root}" -xdev \( -name '*.pacnew' -o -name '*.pacsave' -o -name '*.pacorig' \) -delete
  rm -f -- "${root}/etc/machine-id"
  printf 'uninitialized\n' | install -m 0444 /dev/stdin "${root}/etc/machine-id"
}

create_archive() {
  local image="${image_name}-$(date +%Y.%m.%d)-aarch64.tar.zst"
  msg "Creating ${image}..."
  chmod 0755 -- "${root}"
  bsdtar -cf - -C "${root}" . | zstd -c -T0 >"${out_dir}/${image}.tmp"
  mv -f -- "${out_dir}/${image}.tmp" "${out_dir}/${image}"
  du -h -- "${out_dir}/${image}"
}

# shellcheck source=profile/config.sh
source "${profile}/config.sh"

setup_vm
rm -rf -- "${work_dir}"
mkdir -p -- "${work_dir}"
copy_airootfs
install_packages
install_aur_packages
cleanup_rootfs
create_archive
msg "Done!"
