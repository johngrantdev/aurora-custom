#!/bin/bash
set -eoux pipefail

### Branding
# Patch os-release branding fields only; VERSION/BUILD_ID/OSTREE_VERSION
# are left untouched so they continue to reflect the upstream Aurora build.
sed -i \
    's|^NAME=.*|NAME="Framework OS"|' \
    's|^PRETTY_NAME=.*|PRETTY_NAME="Framework OS (aurora-custom:laptop)"|' \
    's|^LOGO=.*|LOGO=distributor-logo-symbolic|' \
    's|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="framework"|' \
    's|^HOME_URL=.*|HOME_URL="https://github.com/johngrantdev/aurora-custom"|' \
    's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/johngrantdev/aurora-custom"|' \
    's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/johngrantdev/aurora-custom/issues"|' \
    's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/johngrantdev/aurora-custom/issues"|' \
    /etc/os-release
