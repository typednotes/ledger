# syntax=docker/dockerfile:1

FROM docker.io/library/ubuntu:24.04 AS builder
# `unzip` is here for `linen`'s own lakefile, not `ledger`'s: `require linen`
# downloads a pinned DuckDB release archive at lakefile-elaboration time
# (i.e. as part of `lake build`, before any of `ledger`'s own code runs) and
# unpacks it by shelling out to `unzip`. `zlib1g-dev`/`libsecret-1-dev` are
# likewise for `linen`'s own FFI (`ffi/zlib.c`, `ffi/keychain.c`) — `ledger`
# only calls into `linen`'s Postgres/SQL modules, but Lake still builds
# every one of `linen`'s `extern_lib` object files as part of `lake build`,
# so all of its native dependencies are needed here too, not just libpq's.
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates git libpq-dev libssl-dev pkg-config build-essential unzip \
      zlib1g-dev libsecret-1-dev \
    && rm -rf /var/lib/apt/lists/*
RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none
ENV PATH="/root/.elan/bin:${PATH}"

WORKDIR /app
COPY . .

# No crt-file surgery on the toolchain: `lakefile.lean` names `libpq.so`
# outright rather than adding `/usr/lib/<multiarch>` to `-L`, so `-lc` keeps
# resolving to the glibc Lean bundles, which Lean's vendored `Scrt1.o`
# matches (see the libpq section there).
RUN lake build ledger

FROM docker.io/library/debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --no-create-home --uid 10001 ledger
WORKDIR /app
COPY --from=builder /app/.lake/build/bin/ledger /usr/local/bin/ledger
USER ledger
# `/health` (see `Ledger.Health`); Scaleway sets `PORT` to the declared port.
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/ledger"]
