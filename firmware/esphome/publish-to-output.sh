#!/usr/bin/env bash
# Copy a local ESPHome build into firmware/output/ and update the web-flasher manifest.
# Usage: ./publish-to-output.sh <esp32s3-zero|esp32c3-zero|esp32s3-supermini|esp32c3-supermini|atom-matrix>
set -euo pipefail

TARGET="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$(cd "$SCRIPT_DIR/../output" && pwd)"
BUILD_ROOT="$SCRIPT_DIR/.esphome/build"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <esp32s3-zero|esp32c3-zero|esp32s3-supermini|esp32c3-supermini|atom-matrix>"
  exit 1
fi

case "$TARGET" in
  esp32s3-zero)
    BOARD_TYPE=zero; CHIP=esp32s3; CHIP_FAMILY="ESP32-S3"; MANIFEST=manifest-zero.json; MANIFEST_NAME="PrintFarmButton Zero"
    ;;
  esp32c3-zero)
    BOARD_TYPE=zero; CHIP=esp32c3; CHIP_FAMILY="ESP32-C3"; MANIFEST=manifest-zero.json; MANIFEST_NAME="PrintFarmButton Zero"
    ;;
  esp32s3-supermini)
    BOARD_TYPE=supermini; CHIP=esp32s3; CHIP_FAMILY="ESP32-S3"; MANIFEST=manifest-supermini.json; MANIFEST_NAME="PrintFarmButton SuperMini"
    ;;
  esp32c3-supermini)
    BOARD_TYPE=supermini; CHIP=esp32c3; CHIP_FAMILY="ESP32-C3"; MANIFEST=manifest-supermini.json; MANIFEST_NAME="PrintFarmButton SuperMini"
    ;;
  atom-matrix)
    BOARD_TYPE=atom-matrix; CHIP=esp32; CHIP_FAMILY="ESP32"; MANIFEST=manifest-atom-matrix.json; MANIFEST_NAME="PrintFarmButton ATOM Matrix"
    ;;
  *)
    echo "Unknown target: $TARGET"
    exit 1
    ;;
esac

PREFIX="printfarmbutton-${BOARD_TYPE}-${CHIP}"
FACTORY_OUT="${PREFIX}.factory.bin"
OTA_OUT="${PREFIX}.ota.bin"

mkdir -p "$OUTPUT_DIR"

# Prefer the newest ESPHome factory/ota bins under the build tree
FACTORY_SRC="$(find "$BUILD_ROOT" -name '*.factory.bin' -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n1 || true)"
OTA_SRC="$(find "$BUILD_ROOT" -name '*.ota.bin' -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n1 || true)"

if [[ -z "$FACTORY_SRC" ]]; then
  echo "No .factory.bin found under $BUILD_ROOT"
  echo "Build first, e.g.: make build-s3-zero"
  exit 1
fi

cp "$FACTORY_SRC" "$OUTPUT_DIR/$FACTORY_OUT"
md5 -q "$OUTPUT_DIR/$FACTORY_OUT" > "$OUTPUT_DIR/$FACTORY_OUT.md5" 2>/dev/null \
  || md5sum "$OUTPUT_DIR/$FACTORY_OUT" | awk '{print $1}' > "$OUTPUT_DIR/$FACTORY_OUT.md5"

if [[ -n "$OTA_SRC" ]]; then
  cp "$OTA_SRC" "$OUTPUT_DIR/$OTA_OUT"
  OTA_MD5="$(md5 -q "$OUTPUT_DIR/$OTA_OUT" 2>/dev/null || md5sum "$OUTPUT_DIR/$OTA_OUT" | awk '{print $1}')"
  echo "$OTA_MD5" > "$OUTPUT_DIR/$OTA_OUT.md5"
else
  OTA_MD5=""
  echo "Warning: no .ota.bin found; manifest will omit OTA path"
fi

VERSION="$(grep -E '^\s*version:' "$SCRIPT_DIR/conf.d/version.yaml" | head -n1 | sed 's/.*"\(.*\)".*/\1/')"
VERSION="${VERSION:-local}"
MANIFEST_PATH="$OUTPUT_DIR/$MANIFEST"

if [[ ! -f "$MANIFEST_PATH" ]]; then
  jq -n --arg name "$MANIFEST_NAME" --arg version "$VERSION" '{
    name: $name,
    version: $version,
    builds: [],
    new_install_prompt_erase: true
  }' > "$MANIFEST_PATH"
fi

if [[ -n "$OTA_MD5" ]]; then
  NEW_BUILD="$(jq -n \
    --arg chip "$CHIP_FAMILY" \
    --arg factory "$FACTORY_OUT" \
    --arg ota "$OTA_OUT" \
    --arg md5 "$OTA_MD5" \
    '{
      chipFamily: $chip,
      ota: { path: $ota, md5: $md5 },
      parts: [{ path: $factory, offset: 0 }],
      project: "spuder.printfarmbutton"
    }')"
else
  NEW_BUILD="$(jq -n \
    --arg chip "$CHIP_FAMILY" \
    --arg factory "$FACTORY_OUT" \
    '{
      chipFamily: $chip,
      parts: [{ path: $factory, offset: 0 }],
      project: "spuder.printfarmbutton"
    }')"
fi

jq --argjson build "$NEW_BUILD" --arg version "$VERSION" --arg chip "$CHIP_FAMILY" '
  .version = $version
  | .builds = ([.builds[]? | select(.chipFamily != $chip)] + [$build])
' "$MANIFEST_PATH" > "${MANIFEST_PATH}.tmp" && mv "${MANIFEST_PATH}.tmp" "$MANIFEST_PATH"

echo "Published $TARGET → $OUTPUT_DIR/$FACTORY_OUT"
echo "Updated $MANIFEST (version $VERSION, $CHIP_FAMILY)"
echo
echo "Serve the repo root, then open flash.html:"
echo "  cd $(cd "$SCRIPT_DIR/../.." && pwd) && python3 -m http.server 8080"
echo "  open http://localhost:8080/flash.html"
