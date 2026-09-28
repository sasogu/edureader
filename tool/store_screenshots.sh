#!/usr/bin/env bash
# Genera las capturas de las tiendas en simuladores de iOS (solo macOS).
#
#   tool/store_screenshots.sh <carpeta-con-epubs> [salida]
#
# Por defecto usa un iPhone de 6,9" y un iPad de 13", los tamaños que pide
# App Store Connect. Se pueden cambiar con SIM_PHONE y SIM_TABLET (nombres de
# `xcrun simctl list devices`).
set -euo pipefail

epubs="$(cd "${1:?Indica la carpeta con los EPUB}" && pwd)"
out="${2:-store/screenshots/raw}"
bundle_id="es.edutictac.edureader"
devices=("${SIM_PHONE:-iPhone 17 Pro Max}" "${SIM_TABLET:-iPad Pro 13-inch (M5)}")

udid_for() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime in json.load(sys.stdin)["devices"].values():
    for device in runtime:
        if device["name"] == name:
            print(device["udid"]); sys.exit()
sys.exit("Simulador no encontrado: " + name)' "$1"
}

for device in "${devices[@]}"; do
  udid="$(udid_for "$device")"
  folder="$out/$(echo "$device" | tr -cd '[:alnum:]-' )"
  mkdir -p "$folder"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" >/dev/null
  xcrun simctl uninstall "$udid" "$bundle_id" 2>/dev/null || true
  xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi \
    --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
  echo "== $device"
  flutter test integration_test/store_screenshots_test.dart \
    --dart-define=SCREENSHOT_EPUBS="$epubs" -d "$udid" 2>&1 |
    while IFS= read -r line; do
      case "$line" in
        *EDUREADER_SHOT:*)
          name="${line##*EDUREADER_SHOT:}"
          xcrun simctl io "$udid" screenshot "$folder/$name.png" >/dev/null 2>&1
          echo "   captura $name"
          ;;
        *"All tests passed"*|*"Some tests failed"*|*Error*|*EXCEPTION*) echo "$line" ;;
      esac
    done || echo "   la prueba ha fallado en $device"
  xcrun simctl status_bar "$udid" clear
done
