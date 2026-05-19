#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/.." && pwd)"

coverage=0
case "${1:-}" in
  --coverage)
    coverage=1
    shift || true
    ;;
esac

cd "$repo_root"

mkdir -p build/test-results build/coverage
rm -rf build/DerivedData build/test-results/VAEThumbnailKit.xcresult

swift build --product BasicThumbnailCLI

if [[ "$coverage" -eq 1 ]]; then
  xcodebuild test \
    -scheme VAEThumbnailKit-Package \
    -destination 'platform=macOS' \
    -derivedDataPath build/DerivedData \
    -resultBundlePath build/test-results/VAEThumbnailKit.xcresult \
    -enableCodeCoverage YES
else
  xcodebuild test \
    -scheme VAEThumbnailKit-Package \
    -destination 'platform=macOS' \
    -derivedDataPath build/DerivedData
fi