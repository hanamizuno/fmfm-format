# Base images are digest-pinned for reproducible builds; Dependabot (docker ecosystem)
# keeps the digests up to date.
FROM debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# build-essential: the MoonBit native backend compiles through a C toolchain
# DL3008: Debian point releases drop old package versions, so pinning breaks builds
# hadolint ignore=DL3008
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl git build-essential \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# just is pinned by tag; the MoonBit toolchain tracks the latest release because
# cli.moonbitlang.com only hosts `latest` (and `nightly`) binaries.
ARG JUST_VERSION=1.58.0
RUN curl --proto '=https' --tlsv1.2 -fsSL https://just.systems/install.sh \
  | bash -s -- --tag "${JUST_VERSION}" --to /usr/local/bin \
  && curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
ENV PATH="/root/.moon/bin:$PATH"

# ===== Stage 1: development =====
FROM base AS dev

# Node.js executes js-target tests and `moon run --target js` (the default target)
# hadolint ignore=DL3008
RUN apt-get update \
  && apt-get install -y --no-install-recommends nodejs \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Refresh the registry index in its own layer so source-only rebuilds reuse it;
# project dependencies are fetched into .mooncakes/ by the moon check below.
RUN moon update

COPY . /workspace
RUN moon check --deny-warn --target js

CMD ["bash"]

# ===== Stage 2: native release build =====
FROM dev AS build

RUN moon build --release --target native

# ===== Stage 3: production =====
FROM debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f AS prod

# hadolint ignore=DL3008
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --system --gid 10001 app \
  && useradd --system --uid 10001 --gid app --home-dir /app --no-create-home app

WORKDIR /app

# The `fmfm` CLI lives in src/cli (native target)
COPY --from=build /workspace/_build/native/release/build/cli/cli.exe /app/fmfm

# Run as a non-root user (numeric so runtimes can verify runAsNonRoot);
# /app stays root-owned (read-only for the app)
USER 10001:10001

ENTRYPOINT ["/app/fmfm"]
CMD ["--help"]
