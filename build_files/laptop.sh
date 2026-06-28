#!/bin/bash
set -eoux pipefail

### Branding
# Patch os-release branding fields only; VERSION/BUILD_ID/OSTREE_VERSION
# are left untouched so they continue to reflect the upstream Aurora build.
sed -i \
    -e 's|^NAME=.*|NAME="Framework OS"|' \
    -e 's|^PRETTY_NAME=.*|PRETTY_NAME="Framework OS (aurora-custom:laptop)"|' \
    -e 's|^LOGO=.*|LOGO=distributor-logo-symbolic|' \
    -e 's|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="framework"|' \
    -e 's|^HOME_URL=.*|HOME_URL="https://github.com/johngrantdev/aurora-custom"|' \
    -e 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/johngrantdev/aurora-custom"|' \
    -e 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/johngrantdev/aurora-custom/issues"|' \
    -e 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/johngrantdev/aurora-custom/issues"|' \
    /etc/os-release

### Icons — replace aurora logos with framework cog
PLACES=/usr/share/icons/hicolor/scalable/places
SCALABLE=/usr/share/icons/hicolor/scalable

# Remove aurora-specific logo files (symlinks pointing to our cog are kept)
rm -f \
    "${PLACES}/auroralogo-circle-symbolic.svg" \
    "${PLACES}/auroralogo-gradient.svg" \
    "${PLACES}/auroralogo-pride-trans.svg" \
    "${PLACES}/auroralogo-pride.svg" \
    "${PLACES}/auroralogo-white.svg"

# Replace the main distributor-logo.svg (referenced by auroralogo-symbolic.svg etc)
cp "${PLACES}/distributor-logo-symbolic.svg" "${SCALABLE}/distributor-logo.svg"
