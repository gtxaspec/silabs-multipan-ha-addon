# Build environment matching the add-on runtime (HA debian bookworm base); binaries are copied into the add-on.
FROM ghcr.io/home-assistant/amd64-base-debian:bookworm
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake ninja-build pkg-config git ca-certificates patch patchelf \
      libavahi-client-dev libavahi-common-dev libreadline-dev libncurses-dev \
      libnetfilter-queue-dev libsystemd-dev libdbus-1-dev libjsoncpp-dev nodejs npm \
    && rm -rf /var/lib/apt/lists/*
