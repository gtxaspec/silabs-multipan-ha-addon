# Silicon Labs Multiprotocol + Bluetooth

Zigbee (zigbeed, EZSP over TCP), Thread (OpenThread Border Router) and Bluetooth LE
(an HCI adapter for the host's BlueZ) on one Silicon Labs radio running the Simplicity
SDK multiprotocol RCP (`rcp-uart-802154-blehci`, CPC security disabled).

Forked from the retired `silabs-multiprotocol` add-on 2.4.5 and rebuilt on Simplicity
SDK 2025.6.1 and cpcd 4.9.1.

## Requirements

- A radio already flashed with the multiprotocol RCP; this add-on flashes nothing.
- `avahi-daemon` on the host (Home Assistant Supervised): OTBR publishes its mDNS
  services through the host's avahi over D-Bus. Home Assistant OS has no avahi.
- Bluetooth needs the kernel's `hci_uart`, which `btattach` loads on demand.

## Options

- `device` or `network_device`: a local serial port, or `host:port` / `[ipv6]:port`
  of a raw TCP serial bridge such as ser2net.
- `baudrate`, `flow_control`: the RCP's UART settings.
- `zigbee_enable`, `otbr_enable`, `bluetooth_enable`: which stacks run.
- `bluetooth_max_scan_duty`: caps the LE scan window at this percentage of the scan
  interval (100 = no cap). BlueZ scans at 100 %, which leaves the shared radio no
  time to receive 802.15.4.
- `otbr_log_level`, `otbr_firewall`, `cpcd_trace`.

## Using it

- ZHA: radio type EZSP, serial path `socket://local-silabs-multipan:9999`. zigbeed
  listens on the Supervisor network only unless port 9999 is exposed.
- Thread: the OpenThread Border Router integration is discovered.
- Bluetooth: a new adapter shows up in the Bluetooth integration.

If cpcd, zigbeed, otbr-agent or the HCI bridge fails, the add-on stops as a whole
(the radio only recovers when cpcd resets it); enable the watchdog to restart it.
