# Builder image for Phoenix release builds in CI.
#
# The deploy workflow currently reuses the rideclub website-builder image
# (identical Elixir/OTP). Build & push this only if you want Esther Pictures to
# have its own builder (e.g. the runner can't pull the rideclub one). Keep
# ELIXIR_VERSION / ELIXIR_OTP in sync with .tool-versions.
#
# Build for linux/amd64 (the runner + app VM are amd64), even from Apple Silicon:
#
#   docker build --platform=linux/amd64 \
#     -t git.svnmns.com/estherpictures/builder:latest \
#     -f Dockerfile.builder .
#   docker push git.svnmns.com/estherpictures/builder:latest
#
# Then set the workflow's container image to the tag above.
FROM erlang:28-slim

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    ELIXIR_VERSION=1.19.5 \
    ELIXIR_OTP=28

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       ca-certificates curl git openssh-client tar gzip unzip build-essential \
  && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    curl -fsSL "https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/elixir-otp-${ELIXIR_OTP}.zip" -o /tmp/elixir.zip; \
    unzip -q /tmp/elixir.zip -d /opt/elixir; \
    rm /tmp/elixir.zip; \
    ln -s /opt/elixir/bin/elixir  /usr/local/bin/elixir; \
    ln -s /opt/elixir/bin/elixirc /usr/local/bin/elixirc; \
    ln -s /opt/elixir/bin/iex     /usr/local/bin/iex; \
    ln -s /opt/elixir/bin/mix     /usr/local/bin/mix

RUN mix local.hex --force && mix local.rebar --force

CMD ["/bin/bash"]
