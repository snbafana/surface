#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="/Applications/Surface.app"
IDLE_SECONDS=130
OUTPUT_DIR=".build/surface-status"

usage() {
  cat >&2 <<USAGE
usage: $0 [--app /path/to/Surface.app] [--idle-seconds seconds] [--output .build/surface-status]

Relaunches Surface, presses Option-E to show/hide, waits through the idle window,
presses Option-E again, then writes logs and a screenshot under the output dir.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_BUNDLE="${2:?missing value for --app}"
      shift 2
      ;;
    --idle-seconds)
      IDLE_SECONDS="${2:?missing value for --idle-seconds}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:?missing value for --output}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Surface app bundle not found: $APP_BUNDLE" >&2
  exit 1
fi
APP_BUNDLE="$(cd "$(dirname "$APP_BUNDLE")" && pwd)/$(basename "$APP_BUNDLE")"

if ! [[ "$IDLE_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "--idle-seconds must be an integer" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p "$OUTPUT_DIR"

LOG_FILE="$OUTPUT_DIR/alt-e-verify.log"
SUMMARY_FILE="$OUTPUT_DIR/alt-e-verify.txt"
SCREENSHOT_FILE="$OUTPUT_DIR/alt-e-verify.png"
HIDDEN_BEFORE_SCREENSHOT="$OUTPUT_DIR/alt-e-hidden-before.png"
INITIAL_SHOW_SCREENSHOT="$OUTPUT_DIR/alt-e-initial-show.png"
INITIAL_HIDE_SCREENSHOT="$OUTPUT_DIR/alt-e-initial-hide.png"
POST_IDLE_SHOW_SCREENSHOT="$OUTPUT_DIR/alt-e-post-idle-show.png"

kill_matching() {
  local pattern="$1"
  while IFS= read -r pid; do
    kill "$pid" >/dev/null 2>&1 || true
  done < <(pgrep -f "$pattern" || true)
}

press_option_e() {
  /usr/bin/swift -e 'import CoreGraphics; import Darwin
let source = CGEventSource(stateID: .hidSystemState)
let down = CGEvent(keyboardEventSource: source, virtualKey: 14, keyDown: true)!
down.flags = [.maskAlternate]
down.post(tap: .cghidEventTap)
usleep(50_000)
let up = CGEvent(keyboardEventSource: source, virtualKey: 14, keyDown: false)!
up.flags = [.maskAlternate]
up.post(tap: .cghidEventTap)
usleep(750_000)'
}

capture_screen() {
  /usr/sbin/screencapture -x "$1"
}

overlay_delta() {
  /opt/homebrew/bin/python3 - "$1" "$2" <<'PY'
from PIL import Image, ImageChops, ImageStat
import sys

before = Image.open(sys.argv[1]).convert("RGB")
after = Image.open(sys.argv[2]).convert("RGB")
if before.size != after.size:
    raise SystemExit("1000000")

w, h = before.size
regions = [
    (int(w * 0.04), int(h * 0.06), int(w * 0.46), int(h * 0.25)),
    (int(w * 0.50), int(h * 0.06), int(w * 0.84), int(h * 0.35)),
    (int(w * 0.62), int(h * 0.34), int(w * 0.96), int(h * 0.61)),
]

weighted = 0.0
area = 0
for box in regions:
    diff = ImageChops.difference(before.crop(box), after.crop(box))
    stat = ImageStat.Stat(diff)
    box_area = (box[2] - box[0]) * (box[3] - box[1])
    weighted += (sum(stat.mean) / 3.0) * box_area
    area += box_area

print(f"{weighted / max(area, 1):.3f}")
PY
}

assert_overlay_changed() {
  local before="$1"
  local after="$2"
  local label="$3"
  local delta

  delta="$(overlay_delta "$before" "$after")"
  if /opt/homebrew/bin/python3 - "$delta" <<'PY'
import sys
raise SystemExit(0 if float(sys.argv[1]) >= 8.0 else 1)
PY
  then
    echo "$label delta=$delta"
  else
    echo "Expected visible overlay change after $label; screenshot delta=$delta" >&2
    return 1
  fi
}

collect_logs() {
  local start_time="$1"
  for _ in 1 2 3 4 5; do
    /usr/bin/log show \
      --start "$start_time" \
      --info \
      --style compact \
      --predicate 'subsystem == "com.snbafana.Surface"' >"$LOG_FILE" || true

    if grep -q "Shortcut fired" "$LOG_FILE"; then
      return 0
    fi
    sleep 1
  done
}

pkill -x Surface >/dev/null 2>&1 || true
kill_matching "/Surface[.]app/Contents/MacOS/App$"
sleep 1

/usr/bin/open -n "$APP_BUNDLE"
sleep 2

PID="$(pgrep -x Surface | head -n 1 || true)"
if [[ -z "$PID" ]]; then
  echo "Surface did not launch from $APP_BUNDLE" >&2
  exit 1
fi

PROCESS_PATH="$(lsof -a -p "$PID" -Fn 2>/dev/null | sed -n 's/^n//p' | grep -E '/Surface[.]app/Contents/MacOS/(Surface|App)$' | head -n 1 || true)"
case "$PROCESS_PATH" in
  "$APP_BUNDLE"/Contents/MacOS/Surface|"$APP_BUNDLE"/Contents/MacOS/App)
    ;;
  *)
    echo "Surface launched from an unexpected executable: ${PROCESS_PATH:-unknown}" >&2
    echo "Expected bundle: $APP_BUNDLE" >&2
    exit 1
    ;;
esac

START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"

capture_screen "$HIDDEN_BEFORE_SCREENSHOT"
press_option_e
sleep 1
capture_screen "$INITIAL_SHOW_SCREENSHOT"
assert_overlay_changed "$HIDDEN_BEFORE_SCREENSHOT" "$INITIAL_SHOW_SCREENSHOT" "initial show"

press_option_e
sleep 1
capture_screen "$INITIAL_HIDE_SCREENSHOT"

if [[ "$IDLE_SECONDS" -gt 0 ]]; then
  sleep "$IDLE_SECONDS"
fi

press_option_e
sleep 1
capture_screen "$POST_IDLE_SHOW_SCREENSHOT"
assert_overlay_changed "$INITIAL_HIDE_SCREENSHOT" "$POST_IDLE_SHOW_SCREENSHOT" "post-idle show"

cp "$POST_IDLE_SHOW_SCREENSHOT" "$SCREENSHOT_FILE"
collect_logs "$START_TIME"

SHORTCUT_COUNT="$(grep -c "Shortcut fired" "$LOG_FILE" || true)"
SHOWN_COUNT="$(grep -c "Panel shown" "$LOG_FILE" || true)"
REASSERT_COUNT="$(grep -c "Panel reasserted" "$LOG_FILE" || true)"
RECOVERY_COUNT="$(grep -c "Shortcut recovery succeeded" "$LOG_FILE" || true)"
INITIAL_DELTA="$(overlay_delta "$HIDDEN_BEFORE_SCREENSHOT" "$INITIAL_SHOW_SCREENSHOT")"
POST_IDLE_DELTA="$(overlay_delta "$INITIAL_HIDE_SCREENSHOT" "$POST_IDLE_SHOW_SCREENSHOT")"

{
  echo "app=$APP_BUNDLE"
  echo "pid=$PID"
  echo "processPath=$PROCESS_PATH"
  echo "idleSeconds=$IDLE_SECONDS"
  echo "initialShowDelta=$INITIAL_DELTA"
  echo "postIdleShowDelta=$POST_IDLE_DELTA"
  echo "shortcutFired=$SHORTCUT_COUNT"
  echo "panelShown=$SHOWN_COUNT"
  echo "panelReasserted=$REASSERT_COUNT"
  echo "shortcutRecoverySucceeded=$RECOVERY_COUNT"
  echo "log=$LOG_FILE"
  echo "screenshot=$SCREENSHOT_FILE"
} >"$SUMMARY_FILE"

if [[ ! -s "$SCREENSHOT_FILE" ]]; then
  echo "Screenshot was not written: $SCREENSHOT_FILE" >&2
  cat "$SUMMARY_FILE" >&2
  exit 1
fi

cat "$SUMMARY_FILE"
