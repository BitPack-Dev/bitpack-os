#!/usr/bin/env bash
set -euo pipefail

# Check for root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

HOSTNAME="bitpack"
USERNAME="bitpack-user"
REPO_ROOT="$(pwd)"
OUTPUT_DIR="${REPO_ROOT}/out"
LB_DIR="${REPO_ROOT}/live-build"

log() { echo "[build-bitpack] $*"; }

log "Cleaning up old build files..."
rm -rf "${LB_DIR}" "${OUTPUT_DIR}"
mkdir -p "${LB_DIR}" "${OUTPUT_DIR}"

cd "${LB_DIR}"

log "Initializing live-build config..."
# Fixed: Added --security false to stop the buggy automatic security setup
lb config \
  --mode debian \
  --system live \
  --architectures amd64 \
  --distribution bullseye \
  --bootloader grub-efi \
  --apt-recommends false \
  --debian-installer false \
  --binary-images iso-hybrid \
  --source false \
  --security false \
  --mirror-bootstrap http://deb.debian.org/debian \
  --mirror-binary http://deb.debian.org/debian \
  --archive-areas "main contrib non-free" \
  --checksums sha256

# --- FIX: Manually add the correct Bullseye Security repository ---
log "Adding manual security repositories..."
mkdir -p config/archives
cat > config/archives/security.list.chroot <<EOF
deb http://security.debian.org/debian-security bullseye-security main contrib non-free
EOF
# Also add it for the binary (final ISO)
cp config/archives/security.list.chroot config/archives/security.list.binary

# Prepare Configuration Tree
log "Preparing package lists and hooks..."

mkdir -p config/package-lists
if [ -d "${REPO_ROOT}/config/package-lists" ]; then
    cp -v "${REPO_ROOT}/config/package-lists/"*.list.chroot config/package-lists/ || true
fi

mkdir -p config/includes.chroot
if [ -d "${REPO_ROOT}/config/includes.chroot" ]; then
    cp -a "${REPO_ROOT}/config/includes.chroot/." config/includes.chroot/
fi

# Setup the customization hook
mkdir -p config/hooks/live
cat > config/hooks/live/01-customize.chroot <<EOF
#!/usr/bin/env bash
set -euo pipefail
export BITPACK_OS_HOSTNAME="${HOSTNAME}"
export BITPACK_OS_USERNAME="${USERNAME}"
if [ -f "${REPO_ROOT}/customize.sh" ]; then
    bash "${REPO_ROOT}/customize.sh"
fi
EOF
chmod +x config/hooks/live/01-customize.chroot

log "Starting build (this takes a long time)..."
lb build

log "Locating output ISO..."
ISO_PATH=$(find . -maxdepth 1 -name "*.iso" | head -n 1)

if [[ -z "${ISO_PATH}" ]]; then
  echo "ERROR: ISO was not generated." >&2
  exit 1
fi

mv -v "${ISO_PATH}" "${OUTPUT_DIR}/bitpack-os.iso"

if [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER":"$SUDO_USER" "${OUTPUT_DIR}"
fi

log "Done! ISO is in ${OUTPUT_DIR}/bitpack-os.iso"
