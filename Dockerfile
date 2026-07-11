# Multi-stage build for a Phoenix release, following the official
# hexpm/elixir base images (Elixir/OTP/Debian versions must be kept in sync
# with each other -- see https://hub.docker.com/r/hexpm/elixir/tags).
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.14
ARG DEBIAN_VERSION=bookworm-20260623

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}-slim"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y \
    && apt-get install -y build-essential git ca-certificates curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock* ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# JS deps for the esbuild bundle (highlight.js, etc.). node_modules is
# .dockerignore'd, so install fresh from the committed lockfile.
RUN cd assets && npm ci

# The Tailwind standalone binary is fetched from GitHub by Erlang's :ssl,
# which fails on some OTP versions against GitHub's cert chain. Fetch it
# with curl (system TLS) into the path `mix tailwind` expects, so
# `assets.setup` finds it and skips the download. esbuild's binary comes
# from the npm registry and downloads fine via the mix task.
ARG TAILWIND_VERSION=3.4.3
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) TW_ARCH=linux-x64 ;; \
      arm64) TW_ARCH=linux-arm64 ;; \
      *) echo "unsupported arch"; exit 1 ;; \
    esac; \
    mkdir -p _build; \
    curl -fsSL -o "_build/tailwind-${TW_ARCH}-${TAILWIND_VERSION}" \
      "https://github.com/tailwindlabs/tailwindcss/releases/download/v${TAILWIND_VERSION}/tailwindcss-${TW_ARCH}"; \
    chmod +x "_build/tailwind-${TW_ARCH}-${TAILWIND_VERSION}"

RUN mix assets.setup
RUN mix assets.deploy
RUN mix compile

COPY config/runtime.exs config/
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
    && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV=prod
ENV PHX_SERVER=true
ENV PORT=4000
# Matches litehouse's app-volume convention: a persistent volume mounted at
# /data, with the SQLite file at /data/app.db (see litehouse's src/volume.rs).
ENV DATABASE_PATH=/data/app.db

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/blog ./

RUN mkdir -p /data && chown nobody /data
VOLUME /data

USER nobody

EXPOSE 4000

CMD ["/bin/sh", "-c", "/app/bin/blog eval \"Blog.Release.migrate_and_seed()\" && /app/bin/blog start"]
