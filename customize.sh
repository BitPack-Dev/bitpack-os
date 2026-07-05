#!/usr/bin/env bash
set -euo pipefail

# customize.sh is invoked by live-build hooks.
# It applies branding and best-effort wallpaper/identity changes.

HOSTNAME="${BITPACK_OS_HOSTNAME:-bitpack}"
USERNAME="${BITPACK_OS_USERNAME:-bitpack-user}"

# In most live-build hook contexts, $LB_CHROOT_PATH points at the target filesystem.
CHROOT_PATH="${LB_CHROOT_PATH:-}"

log() { echo "[customize] $*"; }

apply_branding() {
  if [[ -z "${CHROOT_PATH}" ]] || [[ ! -d "${CHROOT_PATH}" ]]; then
    log "CHROOT_PATH not set; branding changes will be best-effort and may not apply to filesystem."
    return 0
  fi

  mkdir -p "${CHROOT_PATH}/etc" "${CHROOT_PATH}/usr/share/xfce4/desktop-icons" || true

  # Hostname
  echo "${HOSTNAME}" >"${CHROOT_PATH}/etc/hostname"
  {
    echo "127.0.0.1 localhost"
    echo "127.0.1.1 ${HOSTNAME}"
  } >"${CHROOT_PATH}/etc/hosts"

  # Issue / motd
  cat >"${CHROOT_PATH}/etc/issue" <<EOF
Bitpack OS Pro\n\nHostname: ${HOSTNAME}\nEOF

  # Branding strings
  cat >"${CHROOT_PATH}/usr/share/bitpack-os-branding.txt" <<EOF
Bitpack OS Pro\nHostname: ${HOSTNAME}\nUser: ${USERNAME}\nEOF

  # os-release (replace Debian mentions)
  if [[ -f "${CHROOT_PATH}/etc/os-release" ]]; then
    sed -i \
      -e 's/^NAME=.*/NAME="Bitpack OS Pro"/' \
      -e 's/^PRETTY_NAME=.*/PRETTY_NAME="Bitpack OS Pro"/' \
      -e 's/^ID=.*/ID=bitpackos/' \
      "${CHROOT_PATH}/etc/os-release" || true
  fi

  log "Branding applied in chroot."
}

apply_user() {
  if [[ -z "${CHROOT_PATH}" ]] || [[ ! -d "${CHROOT_PATH}" ]]; then
    return 0
  fi

  if [[ ! -x "${CHROOT_PATH}/usr/sbin/useradd" && ! -x "${CHROOT_PATH}/usr/sbin/adduser" ]]; then
    log "User management tools not found in chroot; skipping user creation."
    return 0
  fi

  # Create user if missing.
  if ! grep -q "^${USERNAME}:" "${CHROOT_PATH}/etc/passwd" 2>/dev/null; then
    chroot "${CHROOT_PATH}" /usr/sbin/useradd -m -s /bin/bash "${USERNAME}" || \
      chroot "${CHROOT_PATH}" /usr/sbin/adduser --disabled-password --gecos "" "${USERNAME}" || true

    chroot "${CHROOT_PATH}" passwd -l "${USERNAME}" >/dev/null 2>&1 || true
    chroot "${CHROOT_PATH}" usermod -aG sudo "${USERNAME}" >/dev/null 2>&1 || true
  fi

  # Default shell for bitpack user -> zsh
  if chroot "${CHROOT_PATH}" getent passwd "${USERNAME}" >/dev/null 2>&1; then
    # Only change shell if zsh exists.
    if [[ -x "${CHROOT_PATH}/usr/bin/zsh" ]]; then
      chroot "${CHROOT_PATH}" usermod -s /usr/bin/zsh "${USERNAME}" >/dev/null 2>&1 || true
    fi
  fi
}

apply_wallpaper_best_effort() {
  if [[ -z "${CHROOT_PATH}" ]] || [[ ! -d "${CHROOT_PATH}" ]]; then
    return 0
  fi

  mkdir -p "${CHROOT_PATH}/etc/xdg/xfce4" || true

  # XFCE default (fallback). The professional wallpaper is handled by live-build hook download-wallpaper.sh
  cat >"${CHROOT_PATH}/etc/xdg/xfce4/bitpack-os-wallpaper.conf" <<EOF
Bitpack OS Pro\nWallpaper path: /usr/share/backgrounds/bitpack-default.jpg\nEOF
}

apply_branding
apply_user
apply_wallpaper_best_effort

log "Customization complete (best-effort)."

