# shellcheck shell=bash
# Sourced by build.sh

image_name="yabe-rootfs"

# ["<path in rootfs>"]="<uid>:<gid>:<mode>"; a trailing '/' applies recursively
declare -A file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/yabe"]="0:0:777"
)
