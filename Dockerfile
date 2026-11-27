# syntax=docker/dockerfile:1

FROM docker.io/library/ubuntu:24.04 AS builder
# Install native build dependencies from the pinned Linen release.
ARG LINEN_REF=bcfec9a81d6e738ecb273f89e2102b4712d8e160
ADD https://raw.githubusercontent.com/typednotes/linen/${LINEN_REF}/ci/native-deps/apt.txt /tmp/linen-apt.txt
RUN apt-get update && apt-get install -y --no-install-recommends \
      $(sed 's/#.*//' /tmp/linen-apt.txt) \
    && rm -rf /var/lib/apt/lists/*
RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none
ENV PATH="/root/.elan/bin:${PATH}"

WORKDIR /app
COPY . .

RUN lake build ledger

FROM docker.io/library/ubuntu:24.04 AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --no-create-home --uid 10001 ledger
WORKDIR /app
COPY --from=builder /app/.lake/build/bin/ledger /usr/local/bin/ledger
COPY --from=builder /app/.lake/packages/linen/.lake/build/ffi/liblinen_postgres.so /app/.lake/packages/linen/.lake/build/ffi/
USER ledger
# `/health` (see `Ledger.Health`); Scaleway sets `PORT` to the declared port.
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/ledger"]
