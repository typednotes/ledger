# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates git libpq-dev libssl-dev pkg-config build-essential \
    && rm -rf /var/lib/apt/lists/*
RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none
ENV PATH="/root/.elan/bin:${PATH}"

# `require linen` resolves over `git@github.com:typednotes/linen.git` (a
# private repo), so cloning it needs an SSH key — forwarded in via
# BuildKit's `--mount=type=ssh` rather than baked into a layer. The
# corresponding `docker-publish.yml` step runs `ssh-agent` with a deploy key
# and passes `ssh: default` to `docker/build-push-action`.
RUN mkdir -p -m 0700 /root/.ssh && ssh-keyscan github.com >> /root/.ssh/known_hosts

WORKDIR /app
COPY . .
RUN --mount=type=ssh lake build ledger

FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --no-create-home --uid 10001 ledger
WORKDIR /app
COPY --from=builder /app/.lake/build/bin/ledger /usr/local/bin/ledger
USER ledger
ENTRYPOINT ["/usr/local/bin/ledger"]
