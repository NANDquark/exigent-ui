#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

EMSCRIPTEN_SDK_DIR="${EMSCRIPTEN_SDK_DIR:-$HOME/repos/emsdk}"
OUT_DIR="build/raylib_web"
OBJ="$OUT_DIR/exigent_raylib_web.wasm.o"

mkdir -p "$OUT_DIR"

ODIN_PATH="$(odin root)"

odin build demos/raylib_web \
	-target:js_wasm32 \
	-build-mode:obj \
	-no-entry-point \
	-define:RAYLIB_WASM_LIB=env.o \
	-collection:exigent=exigent \
	-collection:raylib_exigent=raylib_exigent \
	-out:"$OBJ"

cp "$ODIN_PATH/core/sys/wasm/js/odin.js" "$OUT_DIR/odin.js"

export EMSDK_QUIET=1
if [[ -f "$EMSCRIPTEN_SDK_DIR/emsdk_env.sh" ]]; then
	# shellcheck disable=SC1091
	. "$EMSCRIPTEN_SDK_DIR/emsdk_env.sh"
fi

emcc -o "$OUT_DIR/index.html" \
	"$OBJ" \
	"$ODIN_PATH/vendor/raylib/wasm/libraylib.a" \
	-sEXPORTED_FUNCTIONS="['_main_start','_main_update','_main_end','_web_window_size_changed']" \
	-sEXPORTED_RUNTIME_METHODS="['HEAPF32']" \
	-sALLOW_MEMORY_GROWTH=1 \
	-sUSE_GLFW=3 \
	-sWASM_BIGINT \
	-sWARN_ON_UNDEFINED_SYMBOLS=0 \
	-sASSERTIONS \
	--shell-file demos/raylib_web/index_template.html

rm -f "$OBJ"

echo "Web demo created in $OUT_DIR"
