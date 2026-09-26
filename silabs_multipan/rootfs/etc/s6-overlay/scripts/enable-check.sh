#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Enable the services the add-on options ask for (S6_STAGE2_HOOK)
# ==============================================================================
readonly rc=/etc/s6-overlay/s6-rc.d

if bashio::config.has_value 'network_device'; then
    touch "${rc}/user/contents.d/socat-cpcd-tcp"
    touch "${rc}/cpcd/dependencies.d/socat-cpcd-tcp"
    bashio::log.info "Enabled socat-cpcd-tcp."
fi

if bashio::config.false 'zigbee_enable'; then
    rm -f "${rc}/user/contents.d/zigbeed"
    bashio::log.info "zigbeed is disabled."
fi

if bashio::config.false 'otbr_enable'; then
    rm -f "${rc}/user/contents.d/otbr-agent" "${rc}/user/contents.d/otbr-agent-rest-discovery" \
        "${rc}/user/contents.d/otbr-web"
    bashio::log.info "otbr-agent is disabled."
fi

if bashio::config.false 'bluetooth_enable'; then
    rm -f "${rc}/user/contents.d/cpc-hci-bridge" "${rc}/user/contents.d/btattach"
    bashio::log.info "Bluetooth is disabled."
fi
