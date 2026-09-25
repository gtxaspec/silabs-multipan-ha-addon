ARG BUILD_FROM
FROM $BUILD_FROM

RUN \
    set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       bluez \
       iproute2 \
       ipset \
       iptables \
       libavahi-client3 \
       libstdc++6 \
       libsystemd0 \
       netcat-openbsd \
       socat \
    && rm -rf /var/lib/apt/lists/*

# Prebuilt by builder/build-bins.sh; the deploy step copies them next to this file.
COPY opt/multipan /opt/multipan
COPY rootfs /

RUN touch /accept_silabs_msla

ENV \
    PATH="/opt/multipan/sbin:/opt/multipan/bin:${PATH}" \
    S6_STAGE2_HOOK=/etc/s6-overlay/scripts/enable-check.sh

WORKDIR /
ENTRYPOINT ["/init"]
