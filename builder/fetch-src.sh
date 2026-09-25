#!/bin/bash
# Assemble build-bins.sh's /src: cpc-daemon v4.9.1, plus zigbeed, the CPC-HCI bridge and OTBR from
# Simplicity SDK 2025.6.1 (the SDK and slc come from the silabs-w1700k firmware builder image).
#   fetch-src.sh SRC_DIR
set -euo pipefail
IMAGE=ghcr.io/hurrian/silabs-w1700k:27b92fe64f4a6d22
SDK=/simplicity_sdk_2025.6.1

if [[ ${1:-} == --in-container ]]; then
  cd /w
  slc signature trust --sdk $SDK >/dev/null
  # Plain linux_arch_64 links zigbeed against the arm64 stack libraries
  slc generate --sdk $SDK --with linux_arch_64,zigbee_x86_64 --without zigbee_recommended_linux_arch \
    --project-file $SDK/protocol/zigbee/app/projects/zigbeed/zigbeed.slcp \
    --export-destination /w/zigbeed -cpsdk -cpproj --new-project --output-type makefile >/w/zigbeed-slc.log
  # -cpsdk leaves out headers the project includes: copy every include directory's headers
  grep -oE '\-I\$\(COPIED_SDK_PATH\)/[^ \\]+' zigbeed/zigbeed.project.mak | sed 's|-I$(COPIED_SDK_PATH)/||' | sort -u |
    while read -r d; do
      [ -d "$SDK/$d" ] || continue
      find "$SDK/$d" -maxdepth 1 \( -name '*.h' -o -name '*.hpp' \) | while read -r f; do
        t=zigbeed/${SDK#/}/${f#"$SDK"/}
        [ -e "$t" ] || { mkdir -p "$(dirname "$t")"; cp "$f" "$t"; }
      done
    done
  mkdir -p otbr sdk-hci
  cp -r $SDK/util/third_party/ot-br-posix otbr/ot-br-posix
  cp -r $SDK/util/third_party/openthread otbr/openthread
  cp -r $SDK/protocol/openthread/platform-abstraction/posix otbr/silabs-vendor-interface
  for d in app/bluetooth/example_host/bt_host_cpc_hci_bridge app/bluetooth/component_host app/bluetooth/common_host \
           platform/common/inc protocol/bluetooth/bgstack/ll/utils/hci_packet app/common/util/app_log; do
    mkdir -p sdk-hci/$d
    cp -r $SDK/$d/. sdk-hci/$d/
  done
  chmod -R a+rwX /w
  exit 0
fi

SRC=${1:?usage: fetch-src.sh SRC_DIR}
PATCHES=$(cd "$(dirname "$0")/../patches" && pwd)
mkdir -p "$SRC"
cd "$SRC"
rm -rf cpc-daemon zigbeed sdk-hci otbr
git clone -q --depth 1 -b v4.9.1 https://github.com/SiliconLabs/cpc-daemon.git
docker run --rm --user root -v "$PWD":/w -v "$(realpath "$0")":/fetch-src.sh:ro "$IMAGE" /fetch-src.sh --in-container
patch -d sdk-hci -p1 -s < "$PATCHES/cpc-hci-bridge/0001-cpc-hci-bridge-clamp-LE-scan-duty-cycle.patch"
