# syntax=docker/dockerfile:1

FROM docker.io/library/ubuntu:24.04 AS builder
# `require linen` builds linen's C shims and links its native libraries as
# part of `lake build` (libpq, OpenSSL, zlib, libsecret; unzip for the DuckDB
# archive its lakefile downloads) — even though `ledger` only calls into its
# Postgres/SQL modules. The list is linen's own (`ci/native-deps/apt.txt`), read
# at the linen version `lakefile.lean` requires, so it cannot drift.
ARG LINEN_REF=v1.9.0
ADD https://raw.githubusercontent.com/typednotes/linen/${LINEN_REF}/ci/native-deps/apt.txt /tmp/linen-apt.txt
RUN apt-get update && apt-get install -y --no-install-recommends \
      $(sed 's/#.*//' /tmp/linen-apt.txt) \
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
