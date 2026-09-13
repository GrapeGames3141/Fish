#!/usr/bin/env bash
# Capture the Play Console phone screenshots from the real build.
#
#   bash tools/capture_store_screenshots.sh
#
# Each shot uses the in-game capture harness (`--capture=`), which runs from an
# in-memory default save and a frozen presentation clock, so reruns are stable.
# Requires a display; Godot must render, so --headless will not work here.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT_DIR="${OUT_DIR:-$ROOT/builds/store/hooked/Phone screenshots}"
WORK_DIR="${WORK_DIR:-$ROOT/.godot-task-cache/store-capture}"
RESOLUTION="${RESOLUTION:-720x1280}"

# Ordered listing sequence: what the game is, then how a fight plays out,
# then what you keep. Play shows these left to right.
SCENARIOS=(
	"01:cedar_ready"
	"02:hatteras_line_out"
	"03:moonlit_line_out"
	"04:hatteras_reeling_high"
	"05:cedar_catch"
	"06:records"
	"07:field_notes"
	"08:waters_middle"
)

mkdir -p "$OUT_DIR" "$WORK_DIR/user"

# The import cache must exist before a non-editor run, or textures load empty.
"$GODOT" --headless --path "$ROOT" --import

for entry in "${SCENARIOS[@]}"; do
	index="${entry%%:*}"
	scenario="${entry#*:}"
	target="$OUT_DIR/Phone screenshots - ${index}.png"
	echo "Capturing ${scenario} -> ${target}"
	"$GODOT" --path "$ROOT" \
		--user-data-dir "$WORK_DIR/user" \
		--resolution "$RESOLUTION" \
		--position 0,0 \
		-- "--capture=${target}" "--capture-scenario=${scenario}"
	[[ -s "$target" ]] || { echo "ERROR: ${scenario} produced no image" >&2; exit 1; }
done

echo "Captured ${#SCENARIOS[@]} phone screenshots into ${OUT_DIR}"
