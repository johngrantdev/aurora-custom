#!/bin/bash
set -eoux pipefail

### Remove packages
dnf5 remove -y firefox firefox-langpacks kcm_ublue

### Remove aurora-specific rebase tooling not applicable to a custom image
rm -f /usr/bin/ublue-rollback-helper
sed -i \
    -e '/^alias switch-stream := rebase-helper$/d' \
    -e '/^alias switch-streams := rebase-helper$/d' \
    -e '/^alias rollback-helper := rebase-helper$/d' \
    -e '/^# Rebase assistant$/{N;N;N;d}' \
    /usr/share/ublue-os/just/system.just

### Add repos

# Mullvad VPN
dnf5 config-manager addrepo --from-repofile=https://repository.mullvad.net/rpm/stable/mullvad.repo

# Netbird
cat <<EOF > /etc/yum.repos.d/netbird.repo
[netbird]
name=netbird
baseurl=https://pkgs.netbird.io/yum/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.netbird.io/yum/repodata/repomd.xml.key
repo_gpgcheck=1
EOF

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Workaround for RPM packages that install to /opt (like mullvad-vpn).
# On ostree/bootc images, /opt is a symlink to var/opt, which causes cpio to fail.
mv /opt /opt.bak
mkdir /opt

# Workaround for RPM packages that try to start systemd services during install.
# We temporarily replace systemctl with a dummy command to prevent build failures.
mv /usr/bin/systemctl /usr/bin/systemctl.bak
ln -s /usr/bin/true /usr/bin/systemctl

dnf5 install -y \
    chezmoi \
    mullvad-vpn \
    netbird \
    tmux

# Restore systemctl
rm /usr/bin/systemctl
mv /usr/bin/systemctl.bak /usr/bin/systemctl

# Move installed files to /var/opt and restore /opt symlink
mkdir -p /var/opt
cp -a /opt/. /var/opt/
rm -rf /opt
mv /opt.bak /opt

### Signing policy — merge sigstoreSigned entry into base image policy.json
python3 << 'PYEOF'
import json, os
path = '/etc/containers/policy.json'
p = json.load(open(path)) if os.path.exists(path) else {'default': [{'type': 'reject'}], 'transports': {}}
p.setdefault('transports', {}).setdefault('docker', {})['ghcr.io/johngrantdev/aurora-custom'] = [
    {'type': 'sigstoreSigned', 'keyPath': '/etc/pki/containers/aurora-custom.pub', 'signedIdentity': {'type': 'matchRepository'}}
]
json.dump(p, open(path, 'w'), indent=2)
PYEOF

### Enable services
systemctl enable mullvad-daemon
systemctl enable netbird
systemctl enable podman.socket
systemctl enable uupd.timer
