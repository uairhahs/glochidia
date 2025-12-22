#!/bin/bash
set -e

# Copy gpm binary to zpkg structure
cp gpm/gpm zpkg/raw/usr/bin/gpm
chmod +x zpkg/raw/usr/bin/gpm

# Create the raw package
mksquashfs zpkg/raw/ gpm.raw -noappend

echo "ZimaOS RAW package created: gpm.raw"
