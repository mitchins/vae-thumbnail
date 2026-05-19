#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
config_path="$repo_root/.swiftlint.yml"

case "${1:-}" in
  --fix|fix)
    fix_mode=1
    shift || true
    ;;
  *)
    fix_mode=0
    ;;
esac

if [ -n "${SWIFTLINT_PATH:-}" ] && [ -x "${SWIFTLINT_PATH}" ]; then
  swiftlint_bin="$SWIFTLINT_PATH"
elif command -v swiftlint >/dev/null 2>&1; then
  swiftlint_bin="$(command -v swiftlint)"
elif [ -x "/opt/homebrew/bin/swiftlint" ]; then
  swiftlint_bin="/opt/homebrew/bin/swiftlint"
elif [ -x "/usr/local/bin/swiftlint" ]; then
  swiftlint_bin="/usr/local/bin/swiftlint"
else
  echo "error: SwiftLint is not installed. Install it with Homebrew or add it to PATH." >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  set -- "$repo_root/Sources" "$repo_root/Tests" "$repo_root/Examples" "$repo_root/Package.swift"
fi

if [ "$fix_mode" -eq 1 ] && [ -z "${CI:-}" ]; then
  "$swiftlint_bin" lint --fix --config "$config_path" --force-exclude "$@"
fi

"$swiftlint_bin" lint --strict --config "$config_path" --force-exclude "$@"