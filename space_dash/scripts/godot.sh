#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Writable Godot/font caches in restricted cloud environments. No credentials.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$project_root/.local/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$project_root/.local/cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$project_root/.local/share}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$project_root/artifacts"
exec godot --path "$project_root" "$@"
