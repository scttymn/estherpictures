# Production image for Coolify (and any Docker host).
#
# Build on Debian bookworm so bcrypt/exqlite NIFs match a bookworm/OpenSSL 3.0
# runtime. Keep Elixir/OTP tags in sync with .tool-versions.
#
#   docker build -t estherpictures .
#   docker run --rm -p 4000:4000 \
#     -e SECRET_KEY_BASE=... -e PHX_HOST=estherpictures.com \
#     -e DATABASE_PATH=/opt/estherpictures/data/esther_pictures.db \
#     -v esther_data:/opt/estherpictures/data \
#     estherpictures

ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.1.1
ARG DEBIAN_VERSION=bookworm-20260623-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
       build-essential git curl ca-certificates gnupg \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

# Cache deps separately from app code
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.get --only prod \
  && mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets
COPY rel rel

RUN mix compile \
  && mix assets.setup \
  && mix assets.deploy \
  && mix release

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------
FROM ${RUNNER_IMAGE} AS production

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
       libstdc++6 openssl libncursesw6 locales ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod \
    PHX_SERVER=true \
    PORT=4000 \
    DATABASE_PATH=/opt/estherpictures/data/esther_pictures.db \
    HOME=/opt/estherpictures

WORKDIR /opt/estherpictures

RUN useradd --system --create-home --home-dir /opt/estherpictures --shell /usr/sbin/nologin app \
  && mkdir -p /opt/estherpictures/data/uploads/clips \
  && chown -R app:app /opt/estherpictures

# Release includes rel/overlays/bin/* (server, migrate, docker-entrypoint)
COPY --from=builder --chown=app:app /app/_build/prod/rel/esther_pictures ./

USER app
EXPOSE 4000

CMD ["/opt/estherpictures/bin/docker-entrypoint"]

# Coolify auto-deploy webhook verified

# Houston builds dev (houston dev), test (houston test) and production
# (deploys). Plain `docker build` builds the last stage; pass --target
# production for the production image.

# -----------------------------------------------------------------------------
# Dev: the builder's toolchain, plus inotify-tools for live reload. Compiled
# dependencies live outside the mounted folder (MIX_DEPS_PATH, MIX_BUILD_ROOT).
# -----------------------------------------------------------------------------
FROM ${BUILDER_IMAGE} AS dev

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
       build-essential git curl ca-certificates gnupg inotify-tools \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=dev \
    MIX_DEPS_PATH=/mix/deps \
    MIX_BUILD_ROOT=/mix/_build

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get && mix deps.compile

CMD ["sh", "-c", "mix ecto.create --quiet && mix ecto.migrate && exec mix phx.server"]

# -----------------------------------------------------------------------------
# Test: the app's code on the dev toolchain (houston test runs mix test).
# -----------------------------------------------------------------------------
FROM dev AS test

ENV MIX_ENV=test
COPY . .
RUN mix deps.get && mix compile
