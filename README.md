# Home Assistant Add-on: Silicon Labs Multiprotocol + Bluetooth

Zigbee, Thread and Bluetooth LE from one Silicon Labs radio running the Simplicity SDK
multiprotocol RCP (`rcp-uart-802154-blehci`):

- **Zigbee**: zigbeed speaks EZSP over TCP, so ZHA uses it like any network coordinator
- **Thread**: the OpenThread Border Router, discovered by Home Assistant's OTBR integration
- **Bluetooth**: `cpc-hci-bridge` plus `btattach` give the host's BlueZ a new HCI adapter

It is a fork of Home Assistant's retired `silabs-multiprotocol` add-on 2.4.5 (kept unmodified in
`upstream/` for comparison), moved to Simplicity SDK 2025.6.1 and cpcd 4.9.1, with Bluetooth
added. Tested on Home Assistant Supervised (amd64) with a Gemtek W1700K's EFR32MG21 reached over
ser2net.

## Layout

- `silabs_multipan/`: the add-on (options and usage in its `DOCS.md`)
- `patches/`: changes to Silicon Labs sources
  - `zigbeed/`: EZSP over a TCP socket (upstream's patch, ported), an EZSP reset answered in
    about 1 s instead of 5 (bellows gives up after 2.5 s), and two fixes to the host token file:
    indexed tokens written at the wrong offset (Silicon Labs' fix from SiSDK 2025.6.3), and the
    file grown without being mapped again, which crashed zigbeed on its next start
  - `cpc-interface/`: OpenThread's CPC radio interface, used by zigbeed and otbr-agent: retry the
    endpoint open while the RCP reopens it, and deliver the faked spinel reset response when the
    driver actually waits for it
  - `cpc-hci-bridge/`: cap the LE scan duty cycle; BlueZ scans at 100 %, which leaves the shared
    radio no time to receive 802.15.4
  - `otbr/`: OpenThread's own TCP off in Silicon Labs' posix config; with it on, the border
    router host cannot open a TCP connection to any Thread device
  - `ot-br-posix/`: the OpenThread web UI's topology page, served through Home Assistant ingress
- `builder/`: builds the binaries the add-on image copies in

## Building

The add-on image copies prebuilt binaries from `silabs_multipan/opt/multipan`; nothing is
published to a registry yet, so it installs as a local add-on.

```sh
docker build -t multipan-builder:bookworm builder
builder/fetch-src.sh "$PWD/work/src"
docker run --rm --entrypoint "" \
    -v "$PWD/work/src:/src:ro" -v "$PWD/work/out:/out" -v "$PWD/work/build:/build" \
    -v "$PWD/patches:/patches:ro" -v "$PWD/builder/build-bins.sh:/build-bins.sh:ro" \
    multipan-builder:bookworm /build-bins.sh all
cp -a work/out/opt silabs_multipan/
```

`fetch-src.sh` needs Docker and pulls `ghcr.io/hurrian/silabs-w1700k` for the SDK and `slc`.
Then copy `silabs_multipan/` into the Supervisor's local add-on folder (`/addons` from the SSH or
Samba add-on), reload the add-on store and install it.

## Radio firmware

The radio must run the multiprotocol RCP with CPC security disabled
(`cpc_security_secondary_none`). [w1700k-efr32](https://github.com/gtxaspec/w1700k-efr32) builds
it for the Gemtek W1700K and flashes it through the router's own bootloader path.

## License

The add-on and builder are Apache-2.0, like the Home Assistant add-on they derive from. The
files in `patches/` modify Silicon Labs sources covered by the Silicon Labs Master Software
License Agreement and remain under it.
