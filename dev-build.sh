#!/usr/bin/env bash
#
# Build blueos-base and blueos-core locally without pushing to any registry.
# Optionally deploy the resulting image to a target device.
#
# Usage:
#   ./dev-build.sh                                 # build both images
#   ./dev-build.sh --deploy pi@192.168.2.2         # build + deploy to target
#   ./dev-build.sh --base-only                     # build only blueos-base
#   PLATFORM=linux/arm/v7 ./dev-build.sh           # target armv7
#   CORE_DIR=../BlueOS-docker/core ./dev-build.sh  # custom core path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLATFORM="${PLATFORM:-linux/arm64}"
BASE_TAG="${BASE_TAG:-blueos-base:dev}"
CORE_TAG="${CORE_TAG:-blueos-core:dev}"
CORE_DIR="${CORE_DIR:-${SCRIPT_DIR}/../BlueOS-docker/core}"
CACHE_DIR="${CACHE_DIR:-${SCRIPT_DIR}/.buildx-cache}"

DEPLOY_TARGET=""
BASE_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deploy)
            DEPLOY_TARGET="$2"
            shift 2
            ;;
        --base-only)
            BASE_ONLY=true
            shift
            ;;
        -h|--help)
            sed -n '2,/^$/{ s/^# \?//; p }' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

PLATFORM_PAIR="${PLATFORM//\//-}"
BASE_CACHE_DIR="${CACHE_DIR}/${PLATFORM_PAIR}-base"
CORE_CACHE_DIR="${CACHE_DIR}/${PLATFORM_PAIR}-core"

echo "==> Configuration:"
echo "    Platform:   $PLATFORM"
echo "    Base tag:   $BASE_TAG"
echo "    Core tag:   $CORE_TAG"
echo "    Core dir:   $CORE_DIR"
echo "    Cache dir:  $CACHE_DIR"
echo "    Base only:  $BASE_ONLY"
echo "    Deploy to:  ${DEPLOY_TARGET:-<none>}"
echo ""

echo "==> Building blueos-base ($PLATFORM)..."

if [ "$BASE_ONLY" = true ]; then
    docker buildx build \
        --platform "$PLATFORM" \
        --load \
        --cache-from "type=local,src=${BASE_CACHE_DIR}" \
        --cache-to "type=local,dest=${BASE_CACHE_DIR},mode=max" \
        -t "$BASE_TAG" \
        "$SCRIPT_DIR"
    echo "==> Done (base only). Image: $BASE_TAG"
    exit 0
fi

# The docker-container buildx driver can't resolve FROM references against the
# host Docker daemon's image store.  Export the base image as both a Docker
# daemon image (type=docker, equivalent to --load) and an OCI layout on disk
# so the core build can reference it via --build-context ... = oci-layout://...
BASE_OCI_DIR="${CACHE_DIR}/${PLATFORM_PAIR}-base-oci"
docker buildx build \
    --platform "$PLATFORM" \
    --output type=docker \
    --output "type=oci,dest=${BASE_OCI_DIR}.tar" \
    --cache-from "type=local,src=${BASE_CACHE_DIR}" \
    --cache-to "type=local,dest=${BASE_CACHE_DIR},mode=max" \
    -t "$BASE_TAG" \
    "$SCRIPT_DIR"

rm -rf "$BASE_OCI_DIR"
mkdir -p "$BASE_OCI_DIR"
tar -xf "${BASE_OCI_DIR}.tar" -C "$BASE_OCI_DIR"
rm -f "${BASE_OCI_DIR}.tar"

if [ ! -f "$CORE_DIR/Dockerfile" ]; then
    echo "Error: Core Dockerfile not found at $CORE_DIR/Dockerfile" >&2
    echo "Set CORE_DIR to point to the BlueOS-docker/core directory." >&2
    exit 1
fi

echo "==> Building blueos-core ($PLATFORM)..."
docker buildx build \
    --platform "$PLATFORM" \
    --load \
    --cache-from "type=local,src=${CORE_CACHE_DIR}" \
    --cache-to "type=local,dest=${CORE_CACHE_DIR},mode=max" \
    --build-arg "BASE_IMAGE=$BASE_TAG" \
    --build-context "${BASE_TAG}=oci-layout://${BASE_OCI_DIR}" \
    --build-arg "GIT_DESCRIBE_TAGS=0.0.0-dev-0-g00000000" \
    --build-arg "VITE_APP_GIT_DESCRIBE=heads/dev-0-g00000000" \
    -t "$CORE_TAG" \
    "$CORE_DIR"

echo "==> Done! Images:"
echo "    $BASE_TAG"
echo "    $CORE_TAG"

if [ -n "$DEPLOY_TARGET" ]; then
    echo ""
    echo "==> Deploying $CORE_TAG to $DEPLOY_TARGET..."
    docker save "$CORE_TAG" | ssh "$DEPLOY_TARGET" docker load
    echo "==> Deployed successfully."
fi
