# Builder image for Phoenix release builds in CI.
#
# IMPORTANT: base must match (or be older than) the app VM's OpenSSL/glibc, or
# the crypto NIF won't load at runtime. The app VM is Ubuntu 24.04
# (OpenSSL 3.0.13, glibc 2.39), so we build on Debian bookworm (OpenSSL 3.0,
# glibc 2.36) — binaries built there run fine on 24.04 (older runs on newer).
# Do NOT use trixie/erlang:28-slim here: that's OpenSSL 3.4 and fails on 24.04
# with `version 'OPENSSL_3.4.0' not found`.
#
# Keep the Elixir/Erlang in the tag in sync with .tool-versions.
#
# Build for linux/amd64 (runner + VM are amd64), even from Apple Silicon:
#
#   docker build --platform=linux/amd64 \
#     -t git.svnmns.com/estherpictures/builder:latest \
#     -f Dockerfile.builder .
#   docker push git.svnmns.com/estherpictures/builder:latest
FROM hexpm/elixir:1.19.5-erlang-28.1.1-debian-bookworm-20260623-slim

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

# git + openssh-client for checkout and the scp/ssh deploy steps;
# build-essential to compile C NIFs (bcrypt_elixir, exqlite);
# nodejs (20.x) so JS-based actions like actions/checkout can run in-container.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       ca-certificates curl git openssh-client tar gzip build-essential gnupg \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# hex/rebar are installed by the CI job (mix local.hex/rebar) rather than baked
# here — running the BEAM under amd64 emulation at build time (Apple Silicon)
# crashes. The runner is native amd64, so it's a non-issue there.

CMD ["/bin/bash"]
