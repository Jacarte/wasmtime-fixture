FROM --platform=linux/amd64 rust:1.97.0-bookworm@sha256:8fa55b2f3ddf97471ab6a767bfa3f37e6bad0986ba823e75fea57e2a2a5c3073
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates build-essential cmake pkg-config python3 procps && rm -rf /var/lib/apt/lists/*
ENV CARGO_BUILD_JOBS=2 CARGO_PROFILE_DEV_DEBUG=0 CARGO_PROFILE_TEST_DEBUG=0 CARGO_INCREMENTAL=0
WORKDIR /testbed
RUN git init . && git remote add origin https://github.com/bytecodealliance/wasmtime.git && git fetch --depth=1 origin ec63b69f3da9783db784eef6ba67635385926a2a && git checkout --detach FETCH_HEAD && git submodule update --init --recursive --depth=1 && git remote remove origin && git reflog expire --expire=now --all && git gc --prune=now
RUN rustup target add wasm32-wasip1 wasm32-unknown-unknown
RUN cargo fetch --locked
RUN test "$(git rev-parse HEAD)" = ec63b69f3da9783db784eef6ba67635385926a2a && test -z "$(git status --porcelain)" && ! getent passwd 10101
CMD ["sleep", "infinity"]
