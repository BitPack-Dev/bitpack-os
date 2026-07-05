#!/usr/bin/env bash
set -euo pipefail

# Bitpack OS ISO build script using live-build.
# - Hostname: bitpack
# - Default user: bitpack-user

HOSTNAME="bitpack"
USERNAME="bitpack-user"

# Allow override of output dir
OUTPUT_DIR="${OUTPUT_DIR:-./out}"

# Live-build working directory
LB_DIR="${LB_DIR:-./live-build}"

log() { echo "[build-bitpack] $*"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd lb

log "Using live-build dir: ${LB_DIR}"
log "Output dir: ${OUTPUT_DIR}"

rm -rf "${LB_DIR}" "${OUTPUT_DIR}"
mkdir -p "${LB_DIR}" "${OUTPUT_DIR}"

# Base configuration for live-build.
# Keep this minimal but functional.
log "Initializing live-build config..."
# - Debian bullseye is used as a reasonable default baseline.
# - We generate an amd64 ISO.
# - We enable chroot hooks via config/common/hooks.

lb config \
  --architectures amd64 \
  --distribution bullseye \
  --mode debian \
  --bootloaders grub-efi \
  --apt-recommends false \
  --debian-installer false \
  --binary-images iso-hybrid \
  --source false \
  --mirror-bootstrap http://deb.debian.org/debian \
  --mirror-binary http://deb.debian.org/debian \
  --checksums sha256 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --parent "${LB_DIR}"

# Ensure custom package list exists.
mkdir -p config/package-lists config/common/hooks

# Host/user settings via common config files
# live-build reads username/hostname from config files placed under the config tree.

# Write basic live-build defaults into the generated config.
# NOTE: live-build supports these variables in config/common/.
# If live-build version differs, hooks/customization below still applies.

# Hook: customize.sh at build-time to apply branding/wallpaper.
# We also set hostname and user there as a fallback.

HOOKS_DIR="${LB_DIR}/config/common/hooks"
mkdir -p "${HOOKS_DIR}"

cat >"${HOOKS_DIR}/customize" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# This hook runs inside the live-build build process.
# It should be executable.

# Use repository-local customize.sh as the implementation.
# It is expected to live at the repository root.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# Call the repo script with no args.
"${REPO_ROOT}/customize.sh"
EOF
chmod +x "${HOOKS_DIR}/customize"

# Hook that runs during chroot stage, where hostname/user changes are best applied.
cat >"${LB_DIR}/config/chroot-hooks/customize-chroot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# Pass parameters to customize.sh through env vars.
export BITPACK_OS_HOSTNAME="bitpack"
export BITPACK_OS_USERNAME="bitpack-user"

"${REPO_ROOT}/customize.sh" || exit 1
EOF
chmod +x "${LB_DIR}/config/chroot-hooks/customize-chroot"

# Copy our package list into live-build config tree.
# live-build expects config/package-lists/<name>.list.chroot.
# The repo path is config/package-lists.
log "Preparing package list...
"
cp -v "./config/package-lists/pro.list.chroot" "${LB_DIR}/config/package-lists/pro.list.chroot"
# Back-compat: also include the base desktop list
cp -v "./config/package-lists/desktop.list.chroot" "${LB_DIR}/config/package-lists/desktop.list.chroot"

# Use Pro package list as primary
# (live-build will include whatever list(s) are configured by name)
if [[ -d "${LB_DIR}/config" ]]; then
  mkdir -p "${LB_DIR}/config/package-lists"
  # Ensure pro is present even if lb config defaults change.
fi

# Generate the live system and build ISO.
log "Building ISO (this may take a while)..."

cd "${LB_DIR}"

# Clean to ensure reproducibility
lb clean

# The hooks/customizations are already part of config; run build.
# live-build uses `lb build` from inside the config directory.
lb build

cd - >/dev/null

# Find the produced iso and copy it to OUTPUT_DIR for artifact upload.
log "Locating output ISO..."
ISO_PATH=""

# Search typical live-build output locations.
for p in \
  "${LB_DIR}/images/"*.iso \
  "${LB_DIR}/binary/"*.iso \
  "${LB_DIR}/"*.iso; do
  if [[ -f $p ]]; then
    ISO_PATH="$p"
    break
  fi
done

if [[ -z "${ISO_PATH}" ]]; then
  # Fallback: find .iso
  ISO_PATH="$(find "${LB_DIR}" -maxdepth 5 -name '*.iso' | head -n 1 || true)"
fi

if [[ -z "${ISO_PATH}" ]]; then
  echo "ERROR: Could not find built .iso under ${LB_DIR}" >&2
  exit 1
fi

log "Built ISO: ${ISO_PATH}"
cp -v "${ISO_PATH}" "${OUTPUT_DIR}/"

log "Done. ISO copied to: ${OUTPUT_DIR}" 

