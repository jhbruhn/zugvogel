# syntax=docker/dockerfile:1

# zugvogel-pb-base — the PocketBase runtime federfall and eiermann both start from.
#
# Published to ghcr.io/jhbruhn/zugvogel-pb-base by .github/workflows/pb-base.yml,
# tagged `sha-<commit>`. Consumers pin that tag, for the same reason they pin a
# commit hash for the Dart packages: it names one commit and nothing can move it
# later.
#
# ── What belongs in here ───────────────────────────────────────────────────
#
# Everything both apps would otherwise hold a copy of:
#
#   * the PocketBase binary, at one version with verified checksums. It was
#     duplicated in two Dockerfiles, which means two places to bump and two
#     chances to bump only one — and a hook that works on one app's PocketBase
#     and not the other's is a bad afternoon.
#   * the shared `zv_*.js` hook libraries. A vendored copy per app is a copy
#     that drifts; this makes the image the single source and there is nothing
#     left to keep in sync.
#   * the Typst report base.
#   * the entrypoint, which applies migrations BEFORE serve. That ordering is not
#     a nicety: a bootstrap hook running in `onBootstrap` is not guaranteed to
#     see the schema, so it silently does nothing on the first boot of a new
#     instance and works on the second. It belongs to the runtime, not to each
#     app's compose file — eiermann had it in a dev override only, which meant
#     the shipped image was the broken one.
#
# ── What does NOT belong in here ───────────────────────────────────────────
#
# Migrations. A migration is a historical fact: federfall created
# `organisations` under 1700000001 in a file that cannot be retroactively
# replaced, so the same number means something different in eiermann. They are
# copied templates, per app, forever.
#
# App hooks (`*.pb.js`) likewise: they are the app's own wiring. A consumer
# COPYs them into /pb/pb_hooks, where they land beside the zv_* libraries this
# image already put there.

# ── PocketBase fetch ──────────────────────────────────────────────────────────
FROM alpine:3.20 AS pbfetch
# Keep in lockstep across both apps. The JSVM's behaviour is version-specific in
# ways that have cost real time (JSONRaw byte arrays, the view-query parser), so
# "whatever each app happened to pin" is not a position worth holding.
ARG PB_VERSION=0.39.8
ARG TARGETARCH
RUN apk add --no-cache unzip wget ca-certificates
WORKDIR /pb
# Checksums per architecture, verified before unzip. A silent substitution of the
# server binary is the one supply-chain step worth checking by hand.
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) PB_ARCH=amd64; PB_SHA256=3b675575ff0e6dcc5befc85a9644aea6b04ac617ce125ecb2b6989a3c5b5664f ;; \
        arm64) PB_ARCH=arm64; PB_SHA256=d9e44e40f2483b468bb4dd64e12b554aa85941dc5ee9c4bb87aee8fa9e469425 ;; \
        arm)   PB_ARCH=armv7; PB_SHA256=4824b6999c93227a2a544783e4007e57f43b72aac37f2aebbc99fe75055328b9 ;; \
        *)     echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    wget -q "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${PB_ARCH}.zip" -O /tmp/pb.zip; \
    echo "${PB_SHA256}  /tmp/pb.zip" | sha256sum -c -; \
    unzip /tmp/pb.zip -d /pb; \
    rm /tmp/pb.zip; \
    chmod +x /pb/pocketbase

# ── The base runtime ──────────────────────────────────────────────────────────
FROM alpine:3.20
ARG PB_VERSION=0.39.8
# Readable from a running container and from `docker inspect`, so "which
# PocketBase is this?" has an answer that does not require reading a Dockerfile.
ENV ZUGVOGEL_PB_VERSION=${PB_VERSION}
LABEL org.opencontainers.image.source="https://github.com/jhbruhn/zugvogel" \
      org.opencontainers.image.description="PocketBase runtime with the shared zv_* hooks, for federfall and eiermann" \
      org.opencontainers.image.licenses="MIT"

# wget is not incidental: it is what every consumer's healthcheck uses.
RUN apk add --no-cache ca-certificates tzdata wget

COPY --from=pbfetch /pb/pocketbase /usr/local/bin/pocketbase
WORKDIR /pb
RUN mkdir -p /pb/pb_data /pb/pb_hooks /pb/pb_public

# The shared libraries, in the reserved `zv_*` namespace so an app hook can
# never shadow one.
COPY backend/pocketbase/pb_hooks/zv_*.js /pb/pb_hooks/
COPY backend/pocketbase/typst/           /pb/typst/
COPY backend/pocketbase/entrypoint.sh    /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8090
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# No CMD: an app image sets its own, because the flags differ (a publicDir only
# exists where there is an SPA to serve). Inheriting a wrong default silently is
# worse than being made to state it.
