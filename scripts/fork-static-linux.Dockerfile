FROM rust:1.96.1-bookworm

ARG ZIG_VERSION=0.15.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        binutils \
        cmake \
        curl \
        file \
        musl-tools \
        ninja-build \
        xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && rustup component add clippy rustfmt \
    && rustup target add x86_64-unknown-linux-musl \
    && curl --fail --location --silent --show-error \
        "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" \
        --output /tmp/zig.tar.xz \
    && tar -xJf /tmp/zig.tar.xz -C /opt \
    && ln -s "/opt/zig-x86_64-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig \
    && rm /tmp/zig.tar.xz

WORKDIR /src
