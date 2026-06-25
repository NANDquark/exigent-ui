#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"

cd "${repo_root}"

exec odin run demos/karl2d \
	-collection:exigent=. \
	-collection:karl2d=lib/karl2d \
	-collection:karl2d_exigent=karl2d_exigent \
	"$@"
