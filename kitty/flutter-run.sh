#!/usr/bin/env zsh
# Launched by the kitty "MacOS" startup tab.
# Lets you pick a target entrypoint and a device before running the app.

set -e

cd ~/development/obsidian-app/apps/obsidian_app

# --- Pick target (lib/main_*.dart), default: glass -------------------------
targets=("${(@f)$(ls -1 lib/main_*.dart 2>/dev/null)}")

if (( ${#targets[@]} == 0 )); then
  echo "No lib/main_*.dart targets found." >&2
  exec zsh
fi

# Default to the first target whose name contains "glass".
default_index=1
for i in {1..${#targets[@]}}; do
  if [[ "${targets[$i]}" == *glass* ]]; then
    default_index=$i
    break
  fi
done

echo "Select target:"
for i in {1..${#targets[@]}}; do
  marker=""
  [[ $i == $default_index ]] && marker=" (default)"
  echo "  $i) ${targets[$i]}${marker}"
done

read "reply?Target [${default_index}]: "
[[ -z "$reply" ]] && reply=$default_index
if [[ "$reply" != <-> ]] || (( reply < 1 || reply > ${#targets[@]} )); then
  echo "Invalid choice, using default."
  reply=$default_index
fi
TARGET="${targets[$reply]}"
echo "Target: $TARGET\n"

# --- Extra run arguments ---------------------------------------------------
RUN_ARGS=(
  --dart-define-from-file=dart_defines/glass_dev.env
  --dart-define=ENABLE_RPC_LOGGING=true
  --dart-define=ENABLE_DEBUG_RPC=true
  --web-port
  8080
  --web-header=Cross-Origin-Opener-Policy=same-origin
  --web-header=Cross-Origin-Embedder-Policy=require-corp
)

# --- Pick device -----------------------------------------------------------
echo "Detecting devices..."
devices_json="$(fvm flutter devices --machine 2>/dev/null)"

# Parse ids and human-readable labels (preserve order, one per line).
ids=("${(@f)$(print -r -- "$devices_json" | jq -r '.[].id')}")
labels=("${(@f)$(print -r -- "$devices_json" | jq -r '.[] | "\(.name) [\(.targetPlatform)]"')}")

if (( ${#ids[@]} == 0 )); then
  echo "No devices found. Running with Flutter's default selection..."
  fvm flutter run -t "$TARGET" "${RUN_ARGS[@]}"
else
  echo
  PS3=$'\nSelect device to run: '
  select label in "${labels[@]}"; do
    if [[ -n "$label" ]]; then
      device_id="${ids[$REPLY]}"
      echo "\nRunning on: $label ($device_id)\n"
      fvm flutter run -d "$device_id" -t "$TARGET" "${RUN_ARGS[@]}"
      break
    else
      echo "Invalid choice, try again."
    fi
  done
fi

exec zsh
