#!/usr/bin/env bash
set -euo pipefail

# Download a professional 4K dark-themed wallpaper and install it into the ISO.
# Best-effort: if download fails, still exit successfully (build should continue).

TARGET_DIR="${LB_CHROOT_PATH:-/}" 

# In live-build hooks, LB_CHROOT_PATH is usually the target root.
# We'll default to a safe placeholder if not present.
if [[ -n "${LB_CHROOT_PATH:-}" && -d "${LB_CHROOT_PATH}" ]]; then
  ROOT="${LB_CHROOT_PATH}"
else
  ROOT="${PWD}"
fi

ROOT_BG="${ROOT}/usr/share/backgrounds"
mkdir -p "${ROOT_BG}"

OUT_FILE="${ROOT_BG}/bitpack-default.jpg"

# A stable image URL is required; use a fallback gradient if this fails.
# Replace with a preferred wallpaper URL if you have one.
URL="https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=3840&q=80"

# Attempt download.
if command -v curl >/dev/null 2>&1; then
  if ! curl -L --fail --silent --show-error "$URL" -o "${OUT_FILE}"; then
    echo "Wallpaper download failed; continuing without updating image." >&2
    rm -f "${OUT_FILE}" || true
    exit 0
  fi
elif command -v wget >/dev/null 2>&1; then
  if ! wget -qO "${OUT_FILE}" "$URL"; then
    echo "Wallpaper download failed; continuing without updating image." >&2
    rm -f "${OUT_FILE}" || true
    exit 0
  fi
else
  echo "curl/wget not found; skipping wallpaper download." >&2
  exit 0
fi

exit 0

