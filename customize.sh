#!/usr/bin/env bash
set -euo pipefail

# customize.sh is invoked by live-build hooks.
# It applies branding and best-effort identity changes.

HOSTNAME="${BITPACK_OS_HOSTNAME:-bitpack}"
USERNAME="${BITPACK_OS_USERNAME:-bitpack-user}"

# In live-build hook contexts, LB_CHROOT_PATH usually points at the target filesystem.
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
Bitpack OS Pro

Hostname: ${HOSTNAME}
EOF

  # Branding strings
  cat >"${CHROOT_PATH}/usr/share/bitpack-os-branding.txt" <<EOF
Bitpack OS Pro
Hostname: ${HOSTNAME}
User: ${USERNAME}
EOF

  # os-release (replace Debian mentions)
  if [[ -f "${CHROOT_PATH}/etc/os-release" ]]; then
    sed -i \
      -e 's/^NAME=.*/NAME="Bitpack OS Pro"/' \
      -e 's/^PRETTY_NAME=.*/PRETTY_NAME="Bitpack OS Pro"/' \
      -e 's/^ID=.*/ID=bitpackos/' \
      "${CHROOT_PATH}/etc/os-release" || true

    # Generic replacements for any lingering strings.
    sed -i \
      -e 's/Debian/Bitpack OS Pro/g' \
      -e 's/Bitpack OS/Bitpack OS Pro/g' \
      "${CHROOT_PATH}/etc/os-release" || true
  fi

  log "Branding applied in chroot."
}

apply_user_and_zsh() {
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
    if [[ -x "${CHROOT_PATH}/usr/bin/zsh" ]]; then
      chroot "${CHROOT_PATH}" usermod -s /usr/bin/zsh "${USERNAME}" >/dev/null 2>&1 || true
    fi
  fi

  # Best-effort oh-my-zsh install.
  UHOME="${CHROOT_PATH}/home/${USERNAME}"
  mkdir -p "${UHOME}" || true

  if [[ ! -d "${UHOME}/.oh-my-zsh" ]]; then
    if chroot "${CHROOT_PATH}" /usr/bin/test -x /usr/bin/git >/dev/null 2>&1; then
      chroot "${CHROOT_PATH}" /bin/bash -lc \
        "export RUNZSH=no ZSH='${UHOME}/.oh-my-zsh' && \
         git clone https://github.com/ohmyzsh/ohmyzsh.git '${UHOME}/.oh-my-zsh' 2>/dev/null || true" || true
    fi

    # Copy skeleton zshrc if present.
    if [[ -f "${CHROOT_PATH}/etc/skel/.zshrc" ]]; then
      cp -a "${CHROOT_PATH}/etc/skel/.zshrc" "${UHOME}/.zshrc" || true
    fi
  fi
}

apply_wallpaper_fallback() {
  if [[ -z "${CHROOT_PATH}" ]] || [[ ! -d "${CHROOT_PATH}" ]]; then
    return 0
  fi

  mkdir -p "${CHROOT_PATH}/etc/xdg/xfce4" || true

  # XFCE default (fallback). The professional wallpaper is handled by live-build hook
  # config/hooks/live/download-wallpaper.sh.
  cat >"${CHROOT_PATH}/etc/xdg/xfce4/bitpack-os-wallpaper.conf" <<EOF
Bitpack OS Pro
Wallpaper path: /usr/share/backgrounds/bitpack-default.jpg
EOF
}

apply_branding
apply_user_and_zsh
apply_wallpaper_fallback

log "Customization complete (best-effort)."

