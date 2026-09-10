#!/usr/bin/env bash
# Godot バイナリを .tools/ に取得する（.gitignore 済み）。
#
# 目的: Claude が PR を出す前に、ローカルで --import / --check-only /
# validate_scenes を自分で回して壊れたシーンを push しないようにするため。
# CI では chickensoft-games/setup-godot と gdUnit4-action を使うので
# このスクリプトは不要。
#
# 使い方:
#   bash tools/ci/install_godot.sh
#   .tools/godot --headless --path . --import --quit
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_RELEASE="${GODOT_RELEASE:-stable}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.tools"

BIN_NAME="Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64"
ZIP_NAME="${BIN_NAME}.zip"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/${ZIP_NAME}"

mkdir -p "${TOOLS_DIR}"

if [ -x "${TOOLS_DIR}/godot" ] && "${TOOLS_DIR}/godot" --version 2>/dev/null | grep -q "^${GODOT_VERSION}"; then
  echo "Godot ${GODOT_VERSION} is already installed at ${TOOLS_DIR}/godot"
  exit 0
fi

echo "Downloading Godot ${GODOT_VERSION}-${GODOT_RELEASE} ..."
curl -fsSL --retry 3 --retry-delay 2 -o "${TOOLS_DIR}/${ZIP_NAME}" "${URL}"
unzip -o -q "${TOOLS_DIR}/${ZIP_NAME}" -d "${TOOLS_DIR}"
mv -f "${TOOLS_DIR}/${BIN_NAME}" "${TOOLS_DIR}/godot"
chmod +x "${TOOLS_DIR}/godot"
rm -f "${TOOLS_DIR}/${ZIP_NAME}"

"${TOOLS_DIR}/godot" --version
echo "Installed: ${TOOLS_DIR}/godot"
