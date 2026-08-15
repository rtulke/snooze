#!/usr/bin/env bash
# Installs the .deb (from dist/, see build-deb.sh) into a fresh container of
# each target distro via a real `apt-get install` (so the declared python3
# Depends: actually has to resolve, not just `dpkg -i --force-depends`),
# then runs a functional smoke test: help/version, man page lookup, and the
# postinst config seeding (/etc/snooze.conf.example -> /etc/snooze.conf).
# No live Zabbix call here - that needs a real token/instance, out of scope
# for a packaging smoke test; this only proves the package installs cleanly
# and the CLI itself starts up correctly on each target.
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root

RUNTIME=docker
command -v docker >/dev/null 2>&1 || RUNTIME=podman

DEB=$(ls dist/snooze_*_all.deb 2>/dev/null | head -1)
if [ -z "$DEB" ]; then
    echo "no .deb in dist/ - run packaging/build-deb.sh first" >&2
    exit 1
fi

# Same target set as this project's other packaging pipelines (see
# rtulke/cryptc) for consistency, even though snooze itself doesn't need
# per-distro builds.
TARGET_IMAGES=(debian:12-slim debian:13-slim ubuntu:24.04 ubuntu:26.04)

for img in "${TARGET_IMAGES[@]}"; do
    echo "=========================================================="
    echo "== $img <- $DEB"
    echo "=========================================================="
    "$RUNTIME" run --rm \
        -v "$PWD/$DEB:/tmp/snooze.deb:Z,ro" \
        "$img" \
        bash -euxc '
            apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends /tmp/snooze.deb

            snooze --help   >/dev/null
            snooze --version
            # Check via the package manifest, not the filesystem: Debian
            # slim images (see /etc/dpkg/dpkg.cfg.d/docker) path-exclude
            # /usr/share/man/* and /usr/share/doc/* for every package, so
            # the file legitimately is not on disk there even though the
            # package correctly ships and declares it - dpkg -L reflects
            # what the package installed, independent of that image-level
            # stripping policy.
            dpkg -L snooze | grep -qx /usr/share/man/man1/snooze.1.gz
            test -e /etc/snooze.conf.example
            test -e /etc/snooze.conf   # seeded by postinst from the example

            echo "OK: install + help/version + man page + config seeding all worked"
        '
    echo "== $img: PASS"
    echo
done

echo "All targets passed."
