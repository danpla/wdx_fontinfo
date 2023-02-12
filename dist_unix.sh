#!/bin/sh

VERSION=$(sed -n 's/^version=//p' pluginst.inf)

KERNEL=$(uname -s)
case $KERNEL in
    Darwin)
        SYS=macos
        ;;
    *)
        SYS=$(echo $KERNEL | tr '[:upper:]' '[:lower:]')
        ;;
esac

zip \
    "wdx_fontinfo_${VERSION}_${SYS}.zip" \
    CHANGES.txt \
    LICENSE.txt \
    README.md \
    fontinfo.wdx \
    fontinfo.wdx64 \
    pluginst.inf
