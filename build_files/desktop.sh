#!/usr/bin/bash
set -eoux pipefail

### Looking Glass

# looking-glass-client binary
# Verify COPR is still current: https://copr.fedorainfracloud.org/coprs/sentry/looking-glass/
dnf5 -y copr enable sentry/looking-glass
dnf5 install -y looking-glass-client

# kvmfr kernel module (shared memory transport between host and VM)
# Verify COPR is still current: https://copr.fedorainfracloud.org/coprs/hikariknight/looking-glass-kvmfr/
dnf5 -y copr enable hikariknight/looking-glass-kvmfr
dnf5 install -y akmods akmod-kvmfr kernel-devel

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)"
akmods --force --kernels "$KVER"
modinfo "/usr/lib/modules/${KVER}/extra/kvmfr/kvmfr.ko" || \
    modinfo "/usr/lib/modules/${KVER}/extra/kvmfr/kvmfr.ko.xz"

# Allow the kvm group to access the kvmfr device (user must be in the kvm group)
install -Dm644 /dev/null /usr/lib/udev/rules.d/99-kvmfr.rules
printf 'SUBSYSTEM=="kvmfr", OWNER="root", GROUP="kvm", MODE="0660"\n' \
    > /usr/lib/udev/rules.d/99-kvmfr.rules

# Disable COPRs so they don't end up enabled on the final image
dnf5 -y copr disable sentry/looking-glass
dnf5 -y copr disable hikariknight/looking-glass-kvmfr

### VFIO
systemctl enable vfio-rebind-gpu-usb.service

# Regenerate initramfs so dracut.conf.d/99-vfio.conf takes effect.
# Flags mirror Aurora's build_files/base/19-initramfs.sh:
#   --add ostree   REQUIRED for atomic updates — omitting it = unbootable image
#   --no-hostonly  generic initramfs, preserves LUKS/crypt support
#   --reproducible + DRACUT_NO_XATTR=1  deterministic, ostree-commit-friendly
export DRACUT_NO_XATTR=1
dracut --force --no-hostonly --reproducible --add ostree \
    --kver "$KVER" \
    "/usr/lib/modules/${KVER}/initramfs.img"
