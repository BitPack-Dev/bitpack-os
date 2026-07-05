#!/usr/bin/env bash
set -euo pipefail

# Bitpack Shell (BPSH)
# Commands:
#   bp help
#   bp update    -> apt update
#   bp sys       -> basic hw/system stats
#   bp secure    -> check firewall status

subcmd="${1:-help}"
shift || true

usage() {
  cat <<'EOF'
Usage: bp <command>

Commands:
  help      Show this help.
  update    Alias for apt update.
  sys       Show hardware/system stats.
  secure    Check firewall status.
EOF
}

if [[ "${subcmd}" == "help" || "${subcmd}" == "-h" || "${subcmd}" == "--help" ]]; then
  usage
  exit 0
fi

case "${subcmd}" in
  update)
    exec sudo apt update
    ;;
  sys)
    echo "== CPU =="; lscpu 2>/dev/null || true
    echo "\n== Memory =="; free -h 2>/dev/null || true
    echo "\n== Disk =="; lsblk 2>/dev/null || true
    echo "\n== Uptime =="; uptime 2>/dev/null || true
    ;;
  secure)
    if command -v ufw >/dev/null 2>&1; then
      exec sudo ufw status verbose || true
    elif command -v nft >/dev/null 2>&1; then
      exec sudo nft list ruleset || true
    else
      echo "No supported firewall tool found (ufw/nft)."
    fi
    ;;
  *)
    echo "Unknown command: ${subcmd}" >&2
    usage
    exit 1
    ;;
esac

