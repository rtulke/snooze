#!/usr/bin/env bash
# Builds the .deb once - unlike cryptc, snooze has no compiled/native
# dependencies (pure Python 3 stdlib script), so there's no per-distro
# SONAME skew to work around: one 'all'-architecture package installs on
# every target distro that ships python3, no separate builds needed (see
# packaging/test-install.sh for cross-distro install verification instead).
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root

command -v dpkg-buildpackage >/dev/null 2>&1 || {
    echo "dpkg-buildpackage not found - install devscripts and debhelper." >&2
    exit 1
}

mkdir -p dist
rm -f dist/snooze_*.deb

dpkg-buildpackage -us -uc -b

SRC_DEB=$(ls ../snooze_*_all.deb | head -1)
mv "$SRC_DEB" dist/
# dpkg-buildpackage also drops .buildinfo/.changes next to the repo (native
# package, no separate source upload) - clean those up rather than leaving
# them in the parent directory.
rm -f ../snooze_*.buildinfo ../snooze_*.changes

echo
echo "Built package:"
ls -la dist/
