#!/bin/sh
# Build buildabook inside the ada-toolchain container (Alpine edge, gcc-gnat
# 15.x, gprbuild, hbnf, mustache-ada) — the same environment the ada-on-alpine
# aports are built against.  Override the image with IMAGE=...
set -eu

ROOT=$(cd "$(dirname "$0")" && pwd)
IMAGE="${IMAGE:-ada-toolchain:edge}"

case "$(docker image inspect --format '{{.Id}}' "$IMAGE" 2>/dev/null)" in
    "") echo "error: image '$IMAGE' not found; build it with ada-on-alpine's"; echo "       ./build.sh (then ./build-image.sh) first" >&2; exit 1 ;;
esac

docker run -i --rm -v "$ROOT":/repo -w /repo "$IMAGE" sh -s <<'SCRIPT'
set -eu
gprbuild -P buildabook.gpr -p
SCRIPT

echo "==> built $ROOT/buildabook"
