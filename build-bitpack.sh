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

# 1. Clean and Create Fresh Directories
log "Cleaning up old build files..."
rm -rf "${LB_DIR}" "${OUTPUT_DIR}"
mkdir -p "${LB_DIR}" "${OUTPUT_DIR}"

# 2. Initialize live-build
cd "${LB_DIR}"

log "Initializing live-build config for Debian Bullseye..."
# IMPORTANT: We use --mode debian and --system live to force it away from Ubuntu defaults
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
  --mirror-bootstrap http://deb.debian.org/debian \
  --mirror-binary http://deb.debian.org/debian \
  --mirror-chroot-security http://security.debian.org/debian-security \
  --mirror-binary-security http://security.debian.org/debian-security \
  --archive-areas "main contrib non-free" \
  --checksums sha256

# 3. Prepare Configuration Tree
log "Preparing package lists and hooks..."

# Copy package lists from your repo config
mkdir -p config/package-lists
if [ -d "${REPO_ROOT}/config/package-lists" ]; then
    cp -v "${REPO_ROOT}/config/package-lists/"*.list.chroot config/package-lists/ || true
fi

# Copy includes (your custom files)
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
# Execute your customize script from the repo root
if [ -f "${REPO_ROOT}/customize.sh" ]; then
    bash "${REPO_ROOT}/customize.sh"
fi
EOF
chmod +x config/hooks/live/01-customize.chroot

# 4. Build the ISO
log "Starting build (this takes a long time)..."
# We do NOT run lb clean here because we already wiped the folder at the start
lb build

# 5. Export Output
log "Locating output ISO..."
ISO_PATH=$(find . -maxdepth 1 -name "*.iso" | head -n 1)

if [[ -z "${ISO_PATH}" ]]; then
  echo "ERROR: ISO was not generated. Check the logs above for errors." >&2
  exit 1
fi

mv -v "${ISO_PATH}" "${OUTPUT_DIR}/bitpack-os.iso"

# Fix permissions so GitHub Actions can upload the artifact
if [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER":"$SUDO_USER" "${OUTPUT_DIR}"
fi

log "Done! ISO is in ${OUTPUT_DIR}/bitpack-os.iso"
