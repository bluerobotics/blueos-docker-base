#!/usr/bin/env bash
#
# Build blueos-base and blueos-core for multiple platforms and push to Docker Hub.
#
# Requires QEMU binfmt handlers for cross-platform builds. Install them with:
#   docker run --rm --privileged tonistiigi/binfmt --install arm,arm64
#
# Usage:
#   ./dev-push.sh <tag>                              # push as joaoantoniocardoso/blueos-core:<tag>
#   ./dev-push.sh 1.4.4-next.4                       # example
#   PLATFORMS="linux/arm/v7" ./dev-push.sh <tag>      # single platform
#   REPO=myuser/blueos-core ./dev-push.sh <tag>       # custom repo
#   CORE_DIR=../BlueOS-docker/core ./dev-push.sh <tag>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLATFORMS="${PLATFORMS:-linux/arm/v7,linux/arm64}"
BASE_TAG="${BASE_TAG:-blueos-base:dev}"
REPO="${REPO:-joaoantoniocardoso/blueos-core}"
CORE_DIR="${CORE_DIR:-${SCRIPT_DIR}/../BlueOS-docker/core}"
CACHE_DIR="${CACHE_DIR:-${SCRIPT_DIR}/.buildx-cache}"
BUILDER="${BUILDER:-multiarch-builder}"

if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    sed -n '2,/^$/{ s/^# \?//; p }' "$0"
    exit 0
fi

PUSH_TAG="$1"
FULL_TAG="${REPO}:${PUSH_TAG}"

if [ ! -f "$CORE_DIR/Dockerfile" ]; then
    echo "Error: Core Dockerfile not found at $CORE_DIR/Dockerfile" >&2
    echo "Set CORE_DIR to point to the BlueOS-docker/core directory." >&2
    exit 1
fi

# Collect per-platform cache-from flags
CACHE_FROM_BASE=()
CACHE_FROM_CORE=()
IFS=',' read -ra PLAT_LIST <<< "$PLATFORMS"
for plat in "${PLAT_LIST[@]}"; do
    pair="${plat//\//-}"
    base_cache="${CACHE_DIR}/${pair}-base"
    core_cache="${CACHE_DIR}/${pair}-core"
    [[ -d "$base_cache" ]] && CACHE_FROM_BASE+=(--cache-from "type=local,src=${base_cache}")
    [[ -d "$core_cache" ]] && CACHE_FROM_CORE+=(--cache-from "type=local,src=${core_cache}")
done

echo "==> Configuration:"
echo "    Platforms:  $PLATFORMS"
echo "    Base tag:   $BASE_TAG"
echo "    Push tag:   $FULL_TAG"
echo "    Core dir:   $CORE_DIR"
echo "    Cache dir:  $CACHE_DIR"
echo "    Builder:    $BUILDER"
echo ""

# Build base for all platforms as an OCI layout so the core build can
# reference it via --build-context regardless of the buildx driver.
BASE_OCI_DIR="${CACHE_DIR}/multiarch-base-oci"

echo "==> Building ${BASE_TAG} (${PLATFORMS}) as OCI layout..."
docker buildx build \
    --builder "$BUILDER" \
    --platform "$PLATFORMS" \
    --output "type=oci,dest=${BASE_OCI_DIR}.tar" \
    "${CACHE_FROM_BASE[@]}" \
    -t "$BASE_TAG" \
    "$SCRIPT_DIR"

rm -rf "$BASE_OCI_DIR"
mkdir -p "$BASE_OCI_DIR"
tar -xf "${BASE_OCI_DIR}.tar" -C "$BASE_OCI_DIR"
rm -f "${BASE_OCI_DIR}.tar"

echo "==> Building and pushing ${FULL_TAG} (${PLATFORMS})..."
docker buildx build \
    --builder "$BUILDER" \
    --platform "$PLATFORMS" \
    --push \
    "${CACHE_FROM_CORE[@]}" \
    --build-arg "BASE_IMAGE=${BASE_TAG}" \
    --build-context "${BASE_TAG}=oci-layout://${BASE_OCI_DIR}" \
    --build-arg "GIT_DESCRIBE_TAGS=0.0.0-dev-0-g00000000" \
    --build-arg "VITE_APP_GIT_DESCRIBE=heads/dev-0-g00000000" \
    -t "$FULL_TAG" \
    "$CORE_DIR"

echo ""
echo "==> Pushed: $FULL_TAG"
echo "    Verify: docker buildx imagetools inspect $FULL_TAG"
