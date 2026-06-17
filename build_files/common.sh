#!/bin/bash
set -eoux pipefail

### Remove packages
dnf5 remove -y firefox firefox-langpacks

### Add repos

# Mullvad VPN
dnf5 config-manager addrepo --from-repofile=https://repository.mullvad.net/rpm/stable/mullvad.repo

# Netbird
dnf5 config-manager addrepo --from-repofile=https://pkgs.netbird.io/yum/config.repo

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

dnf5 install -y \
    chezmoi \
    mullvad-vpn \
    netbird \
    tmux

### Enable services
systemctl enable netbird
systemctl enable podman.socket
