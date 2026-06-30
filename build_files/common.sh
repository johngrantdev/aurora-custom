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
    papirus-icon-theme \
    tmux

### Bitwarden CLI
# Not available as an RPM — install official binary from GitHub releases
BW_VERSION="2026.6.0"
curl -fsSL "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip" \
    -o /tmp/bw.zip
unzip /tmp/bw.zip -d /tmp/bw-extract
install -m755 /tmp/bw-extract/bw /usr/bin/bw
rm -rf /tmp/bw.zip /tmp/bw-extract

### Darkly — Qt widget style + KWin window decoration
# Not in any Fedora/Copr repo; built from source.
DARKLY_VERSION="0.5.38"
DARKLY_BUILD_DEPS=(
    cmake gcc-c++ extra-cmake-modules
    qt6-qtbase-devel
    kf6-frameworkintegration-devel
    kf6-kguiaddons-devel
    kf6-ki18n-devel
    kf6-kcmutils-devel
    kf6-kirigami-devel
    kf6-kwindowsystem-devel
    kdecoration-devel
)
dnf5 install -y "${DARKLY_BUILD_DEPS[@]}"
curl -fsSL "https://github.com/Bali10050/Darkly/archive/refs/tags/v${DARKLY_VERSION}.tar.gz" \
    -o /tmp/darkly.tar.gz
tar -xzf /tmp/darkly.tar.gz -C /tmp/
cmake \
    -B /tmp/darkly-build \
    -S "/tmp/Darkly-${DARKLY_VERSION}" \
    -DBUILD_TESTING=OFF \
    -Wno-dev \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
    -DBUILD_QT6=ON \
    -DBUILD_QT5=OFF
cmake --build /tmp/darkly-build -j "$(nproc)"
cmake --install /tmp/darkly-build
rm -rf /tmp/darkly.tar.gz "/tmp/Darkly-${DARKLY_VERSION}" /tmp/darkly-build
dnf5 remove -y --noautoremove "${DARKLY_BUILD_DEPS[@]}"

### KDE Theming — downloaded from GitHub, not in Fedora repos

# Ant-Dark plasma desktop theme (github.com/EliverLara/Ant)
ANT_COMMIT="79ddc06b40ad3a8d0e61a5d1a35af9e9be42ae04"
curl -fsSL "https://github.com/EliverLara/Ant/archive/${ANT_COMMIT}.tar.gz" \
    -o /tmp/ant.tar.gz
tar -xzf /tmp/ant.tar.gz -C /tmp/
cp -r "/tmp/Ant-${ANT_COMMIT}/kde/Dark/plasma/desktoptheme/Ant-Dark" \
    /usr/share/plasma/desktoptheme/Ant-Dark
rm -rf /tmp/ant.tar.gz "/tmp/Ant-${ANT_COMMIT}"

# Advanced Weather Widget plasmoid (github.com/pnedyalkov91/advanced-weather-widget)
AWW_VERSION="1.6.2"
curl -fsSL "https://github.com/pnedyalkov91/advanced-weather-widget/releases/download/${AWW_VERSION}/advanced-weather-widget.plasmoid" \
    -o /tmp/weather-widget.plasmoid
mkdir -p /usr/share/plasma/plasmoids/org.kde.plasma.advanced-weather-widget
unzip /tmp/weather-widget.plasmoid -d /usr/share/plasma/plasmoids/org.kde.plasma.advanced-weather-widget/
rm /tmp/weather-widget.plasmoid

### Network Audio Handling
# plasma-network-audio — KDE module for managing AirPlay/RAOP network audio devices
dnf5 install -y https://github.com/johngrantdev/plasma-network-audio/releases/download/v0.1-alpha.1/plasma-network-audio-0.1-0.alpha_1.fc44.x86_64.rpm
# disable raop-discover auto-sink creation
# Removes the symlink that enables libpipewire-module-raop-discover, which
# auto-creates audio sinks for any AirPlay/RAOP device on the network.
# libpipewire-module-raop-sink remains available for explicit connections.
rm /usr/share/pipewire/pipewire.conf.d/50-raop.conf

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
