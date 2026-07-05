#!/usr/bin/env bash
set -euo pipefail

# Bitpack default wallpaper (download a professional 4K dark-themed image)
# Best-effort: if download fails, exit 0.

ROOT="${LB_CHROOT_PATH:-/}"

# live-build hook runs with env var LB_CHROOT_PATH pointing at the chroot root.
if [[ -z "${ROOT}" || ! -d "${ROOT}" ]]; then
  ROOT="/" 
fi

mkdir -p "${ROOT}/usr/share/backgrounds" 
OUT_FILE="${ROOT}/usr/share/backgrounds/bitpack-default.jpg"

URL="https://images.unsplash.com/photo-1545239351-1141bd82e8a6?auto=format&fit=crop&w=3840&q=80"

if command -v curl >/dev/null 2>&1; then
  curl -L --fail --silent --show-error "$URL" -o "$OUT_FILE" || true
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$OUT_FILE" "$URL" || true
else
  true
fi

exit 0

