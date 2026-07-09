#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

exec odin run demos/layers \
	-collection:exigent=.\
	-collection:raylib_exigent=raylib_exigent
