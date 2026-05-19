#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

case "${1:-}" in
  --lint|lint)
    lint_mode=1
    shift || true
    ;;
  *)
    lint_mode=0
    ;;
esac

if [ -n "${SWIFTFORMAT_PATH:-}" ] && [ -x "${SWIFTFORMAT_PATH}" ]; then
  swiftformat_bin="$SWIFTFORMAT_PATH"
elif command -v swiftformat >/dev/null 2>&1; then
  swiftformat_bin="$(command -v swiftformat)"
elif [ -x "/opt/homebrew/bin/swiftformat" ]; then
  swiftformat_bin="/opt/homebrew/bin/swiftformat"
elif [ -x "/usr/local/bin/swiftformat" ]; then
  swiftformat_bin="/usr/local/bin/swiftformat"
else
  echo "error: SwiftFormat is not installed. Install it with Homebrew or add it to PATH." >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  set -- "$repo_root/Sources" "$repo_root/Tests" "$repo_root/Examples" "$repo_root/Package.swift"
fi

if [ "$lint_mode" -eq 1 ]; then
  "$swiftformat_bin" --lint --swift-version 5.10 --max-width 120 --trailing-commas never "$@"
else
  "$swiftformat_bin" --swift-version 5.10 --max-width 120 --trailing-commas never "$@"
fi