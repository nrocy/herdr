#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT
readonly IMAGE="herdr-fork-static-linux:rust-1.96.1-zig-0.15.2"
readonly TARGET="x86_64-unknown-linux-musl"
readonly CACHE_ROOT="${REPO_ROOT}/target/fork-static-cache"
readonly OUTPUT_DIR="${REPO_ROOT}/target/fork"
readonly OUTPUT="${OUTPUT_DIR}/herdr-linux-x86_64"
readonly VENDORED_ZIG_OUT="${REPO_ROOT}/vendor/libghostty-vt/zig-out"

usage() {
    echo "usage: $0 check|build" >&2
    exit 2
}

[[ $# -eq 1 ]] || usage
readonly ACTION="$1"
[[ "$ACTION" == "check" || "$ACTION" == "build" ]] || usage

mkdir -p \
    "${CACHE_ROOT}/cargo" \
    "${CACHE_ROOT}/target" \
    "${CACHE_ROOT}/zig-global" \
    "${CACHE_ROOT}/zig-local" \
    "${CACHE_ROOT}/zig-out" \
    "$VENDORED_ZIG_OUT" \
    "$OUTPUT_DIR"

docker build \
    --file "${SCRIPT_DIR}/fork-static-linux.Dockerfile" \
    --tag "$IMAGE" \
    "$SCRIPT_DIR"

docker_args=(
    run --rm
    --user "$(id -u):$(id -g)"
    --env CARGO_HOME=/cargo
    --env CARGO_TARGET_DIR=/target
    --env HOME=/tmp
    --env "HERDR_FORK_TARGET=${TARGET}"
    --env RUSTUP_HOME=/usr/local/rustup
    --env ZIG_GLOBAL_CACHE_DIR=/zig-global-cache
    --env ZIG_LOCAL_CACHE_DIR=/zig-local-cache
    --volume "${REPO_ROOT}:/src:ro"
    --volume "${CACHE_ROOT}/cargo:/cargo"
    --volume "${CACHE_ROOT}/target:/target"
    --volume "${CACHE_ROOT}/zig-global:/zig-global-cache"
    --volume "${CACHE_ROOT}/zig-local:/zig-local-cache"
    --volume "${CACHE_ROOT}/zig-out:/src/vendor/libghostty-vt/zig-out"
    --volume "${OUTPUT_DIR}:/output"
    "$IMAGE"
)

if [[ "$ACTION" == "check" ]]; then
    docker "${docker_args[@]}" sh -eu -c '
        cargo fmt --all -- --check
        cargo test --locked --target "$HERDR_FORK_TARGET" fork_actionable_notifications
    '
    exit 0
fi

docker "${docker_args[@]}" sh -eu -c '
    cargo build --release --locked --target "$HERDR_FORK_TARGET"
    cp "/target/$HERDR_FORK_TARGET/release/herdr" /output/herdr-linux-x86_64
'

docker run --rm --volume "${OUTPUT}:/herdr:ro" "$IMAGE" sh -eu -c '
    file /herdr
    if readelf --program-headers /herdr | grep -q "Requesting program interpreter"; then
        echo "error: /herdr is dynamically linked" >&2
        exit 1
    fi
'

docker run --rm --volume "${OUTPUT}:/herdr:ro" ubuntu:22.04 /herdr --version
docker run --rm --volume "${OUTPUT}:/herdr:ro" archlinux:base /herdr --version
sha256sum "$OUTPUT"
