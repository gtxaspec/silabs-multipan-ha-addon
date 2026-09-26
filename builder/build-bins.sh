#!/bin/bash
# Build the add-on's host binaries into /out/opt/multipan (run inside multipan-builder:bookworm).
#   /patches: this repo's patches/ (zigbeed/ on the generated project, cpc-interface/ on both OpenThread CPC interfaces,
#             otbr/ on OTBR's Silicon Labs platform files, ot-br-posix/ on OTBR itself)
#   /src: cpc-daemon, zigbeed (slc-generated SiSDK project), sdk-hci (patched bridge), otbr/{ot-br-posix,openthread,silabs-vendor-interface}
set -euo pipefail
P=/opt/multipan; O=/out$P; B=/build
mkdir -p $O/bin $B
step=${1:-all}

if [[ $step == all || $step == cpcd ]]; then
  cmake -S /src/cpc-daemon -B $B/cpcd -G Ninja -DCMAKE_BUILD_TYPE=Release -DENABLE_ENCRYPTION=FALSE \
        -DCMAKE_INSTALL_PREFIX=$P -DCMAKE_INSTALL_RPATH=$P/lib >/dev/null
  cmake --build $B/cpcd >/dev/null
  DESTDIR=/out cmake --install $B/cpcd >/dev/null
  echo "cpcd: $(ls $O/bin/cpcd) $(ls $O/lib/libcpc.so.*)"
fi

if [[ $step == all || $step == zigbeed ]]; then
  rm -rf $B/zigbeed; cp -r /src/zigbeed $B/zigbeed; cd $B/zigbeed
  for p in /patches/zigbeed/*.patch; do patch -p1 -s < "$p"; done
  for p in /patches/cpc-interface/*.patch; do
    patch -p1 -s -d simplicity_sdk_2025.6.1/protocol/openthread/platform-abstraction/posix < "$p"; done
  sed -i -e "s|^INCLUDES = .*|INCLUDES = -I$O/include|" \
         -e "s|^LD_FLAGS          = .*|LD_FLAGS          = -L$O/lib -Wl,-rpath,$P/lib|" zigbeed.Makefile
  make -f zigbeed.Makefile -j"$(nproc)" >/build/zigbeed-make.log 2>&1 || { grep -E "error" /build/zigbeed-make.log | head; exit 1; }
  install -m 755 build/debug/zigbeed $O/bin/zigbeed
  echo "zigbeed: $(ls $O/bin/zigbeed)"
fi

if [[ $step == all || $step == hci ]]; then
  rm -rf $B/sdk-hci; cp -r /src/sdk-hci $B/sdk-hci; cd $B/sdk-hci/app/bluetooth/example_host/bt_host_cpc_hci_bridge
  PKG_CONFIG_PATH=$O/lib/pkgconfig PKG_CONFIG_SYSROOT_DIR=/out make >/build/hci-make.log 2>&1 || { grep -E "error" /build/hci-make.log | head; exit 1; }
  install -m 755 exe/bt_host_cpc_hci_bridge $O/bin/cpc-hci-bridge
  patchelf --set-rpath $P/lib $O/bin/cpc-hci-bridge
  echo "cpc-hci-bridge: $(ls $O/bin/cpc-hci-bridge)"
fi

if [[ $step == all || $step == otbr ]]; then
  rm -rf $B/otbr; cp -r /src/otbr $B/otbr; cd $B/otbr/ot-br-posix
  for p in /patches/ot-br-posix/*.patch; do patch -p1 -s < "$p"; done
  rmdir third_party/openthread/repo 2>/dev/null || true
  ln -sfn ../../../openthread third_party/openthread/repo
  ln -sf ../../../../silabs-vendor-interface/openthread-core-silabs-posix-config.h \
         ../openthread/src/posix/platform/openthread-core-silabs-posix-config.h
  V=$B/otbr/silabs-vendor-interface
  for p in /patches/cpc-interface/*.patch; do patch -p1 -s -d $V < "$p"; done
  for p in /patches/otbr/*.patch; do patch -p1 -s -d $V < "$p"; done
  cmake -S . -B $B/otbr-out -G Ninja -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$P -DCMAKE_INSTALL_RPATH=$P/lib -DCMAKE_MODULE_PATH=$V \
    -DOTBR_FEATURE_FLAGS=OFF -DOTBR_TELEMETRY_DATA_API=OFF -DOTBR_DNSSD_DISCOVERY_PROXY=ON -DOTBR_SRP_ADVERTISING_PROXY=ON \
    -DOTBR_MDNS=avahi -DOTBR_DBUS=OFF -DOTBR_WEB=ON -DOTBR_BORDER_ROUTING=ON -DOTBR_REST=ON \
    -DOTBR_BACKBONE_ROUTER=ON -DOTBR_INFRA_IF_NAME=eth0 \
    -DOTBR_VENDOR_NAME="Home Assistant" -DOTBR_PRODUCT_NAME="W1700K Multiprotocol" \
    -DOT_MULTIPAN_RCP=ON -DOT_POSIX_RCP_HDLC_BUS=ON -DOT_POSIX_RCP_SPI_BUS=ON -DOT_POSIX_RCP_VENDOR_BUS=ON \
    -DOT_POSIX_CONFIG_RCP_VENDOR_DEPS_PACKAGE=$V/posix_vendor_rcp.cmake \
    -DOT_POSIX_CONFIG_RCP_VENDOR_INTERFACE=$V/cpc_interface.cpp \
    -DCPCD_SOURCE_DIR=/src/cpc-daemon -DENABLE_ENCRYPTION=FALSE \
    -DOT_PLATFORM_CONFIG=openthread-core-silabs-posix-config.h \
    -DCMAKE_C_FLAGS="-I$V" -DCMAKE_CXX_FLAGS="-I$V" >/build/otbr-cmake.log 2>&1 || { tail -30 /build/otbr-cmake.log; exit 1; }
  cmake --build $B/otbr-out >/build/otbr-build.log 2>&1 || { grep -E "error|FAILED" /build/otbr-build.log | head -20; exit 1; }
  DESTDIR=/out cmake --install $B/otbr-out >/dev/null
  echo "otbr: $(ls $O/sbin/otbr-agent $O/sbin/ot-ctl $O/sbin/otbr-web 2>/dev/null | tr '\n' ' ')"
fi
