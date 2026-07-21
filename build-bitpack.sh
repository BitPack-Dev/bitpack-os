#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Bitpack OS ISO build script using live-build.
HOSTNAME="bitpack"
USERNAME="bitpack-user"

# Get the absolute path of the repository root
REPO_ROOT="$(pwd)"
OUTPUT_DIR="${REPO_ROOT}/out"
LB_DIR="${REPO_ROOT}/live-build"

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

# Clean old builds
rm -rf "${LB_DIR}" "${OUTPUT_DIR}"
mkdir -p "${LB_DIR}" "${OUTPUT_DIR}"

# --- IMPORTANT: We must enter the directory BEFORE running lb config ---
cd "${LB_DIR}"

log "Initializing live-build config..."
# Fixed: --bootloader (singular)
# Fixed: Removed --parent (invalid directory flag)
# Fixed: Removed non-free-firmware (not in bullseye)
lb config \
  log "Initializing live-build config..."
lb config \
  --architectures amd64 \
  --distribution bullseye \
  --mode debian \
  --bootloader grub-efi \
  --apt-recommends false \
  --debian-installer false \
  --binary-images iso-hybrid \
  --source false \
  --mirror-bootstrap http://deb.debian.org/debian \
  --mirror-binary http://deb.debian.org/debian \
  --mirror-chroot-security http://security.debian.org/debian-security \
  --mirror-binary-security http://security.debian.org/debian-security \
  --checksums sha256 \
  --archive-areas "main contrib non-free"
  --parent-security-distribution bullseye-security

# Now that config/ is created by lb config, we populate it
log "Preparing configuration tree..."

# Hook: customize-chroot
mkdir -p config/hooks/live
cat > config/hooks/live/01-customize.chroot <<EOF
#!/usr/bin/env bash
set -euo pipefail
export BITPACK_OS_HOSTNAME="${HOSTNAME}"
export BITPACK_OS_USERNAME="${USERNAME}"
# Run the customization script from the repo
"${REPO_ROOT}/customize.sh"
EOF
chmod +x config/hooks/live/01-customize.chroot

# Copy package lists
mkdir -p config/package-lists
cp -v "${REPO_ROOT}/config/package-lists/"*.list.chroot config/package-lists/ || true

# Copy includes (files that go into the OS filesystem)
mkdir -p config/includes.chroot
if [ -d "${REPO_ROOT}/config/includes.chroot" ]; then
    cp -a "${REPO_ROOT}/config/includes.chroot/." config/includes.chroot/
fi

# Generate the live system and build ISO.
log "Building ISO (this may take a while)..."

# Clean to ensure reproducibility
lb clean --all
lb build

# Find the produced iso and copy it to OUTPUT_DIR
log "Locating output ISO..."
ISO_PATH=$(find . -maxdepth 1 -name "*.iso" | head -n 1)

if [[ -z "${ISO_PATH}" ]]; then
  echo "ERROR: Could not find built .iso" >&2
  exit 1
fi

log "Built ISO: ${ISO_PATH}"
cp -v "${ISO_PATH}" "${OUTPUT_DIR}/bitpack-os.iso"

cd "${REPO_ROOT}"
log "Done. ISO copied to: ${OUTPUT_DIR}"

log "Fixing permissions..."
sudo chown -R $USER:$USER "${OUTPUT_DIR}"

if [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER":"$SUDO_USER" "${OUTPUT_DIR}"
    chown -R "$SUDO_USER":"$SUDO_USER" "${LB_DIR}"
fi
