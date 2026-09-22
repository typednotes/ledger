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

# Lean 4.34.0 vendors its own `Scrt1.o`/`crt1.o`/`crti.o`/`crtn.o` (built
# against an old glibc) inside the toolchain's `lib/` dir, and `leanc`
# passes them to the linker by absolute path rather than searching the
# system's own crt files. Those vendored objects still reference the
# `__libc_csu_init`/`__libc_csu_fini` compat symbols glibc >= 2.34 dropped,
# so linking any `lean_exe` against Ubuntu 24.04's glibc (2.39) fails with
# `undefined symbol: __libc_csu_init` — a Lean-toolchain/glibc mismatch,
# unrelated to `ledger`'s or `linen`'s own code. `elan toolchain install`
# forces the toolchain download without yet trying to link anything, so
# the vendored crt files can be overwritten with this image's own
# (glibc-2.39-correct) ones before the real `lake build` link happens.
RUN elan toolchain install "$(cat lean-toolchain)" \
    && toolchain_lib="$(dirname "$(elan which lean)")/../lib" \
    && sys_lib="/usr/lib/$(gcc -dumpmachine)" \
    && cp "$sys_lib/Scrt1.o" "$sys_lib/crt1.o" "$sys_lib/crti.o" "$sys_lib/crtn.o" "$toolchain_lib/"

RUN lake build ledger

FROM docker.io/library/debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --no-create-home --uid 10001 ledger
WORKDIR /app
COPY --from=builder /app/.lake/build/bin/ledger /usr/local/bin/ledger
USER ledger
ENTRYPOINT ["/usr/local/bin/ledger"]
