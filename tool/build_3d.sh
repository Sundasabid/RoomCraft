#!/usr/bin/env bash
# Builds the 3D layer into one HTML file and copies it into the Flutter assets.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/web3d"
[ -d node_modules ] || npm ci
npm run build
mkdir -p "$root/assets/web3d"
cp dist/index.html "$root/assets/web3d/index.html"
echo "3D bundle: $(du -h "$root/assets/web3d/index.html" | cut -f1)"
