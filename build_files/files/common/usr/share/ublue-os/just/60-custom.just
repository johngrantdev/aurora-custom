# vim: set ft=make :

# Set up dotfiles and secrets with chezmoi and Vaultwarden — run once on a new machine
[group('Dotfiles')]
setup-dotfiles:
    #!/usr/bin/env bash
    set -eou pipefail

    echo "==> Configuring Bitwarden CLI..."
    BW_STATUS=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")
    if [[ "$BW_STATUS" == "unauthenticated" ]]; then
        read -rp "Vaultwarden server URL: " BW_SERVER
        bw config server "$BW_SERVER"
    else
        echo "Already authenticated — skipping server config."
    fi

    echo ""
    echo "==> Unlocking Bitwarden vault..."
    BW_STATUS=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")
    if [[ "$BW_STATUS" == "unauthenticated" ]]; then
        BW_SESSION=$(bw login --raw)
    else
        BW_SESSION=$(bw unlock --raw)
    fi
    export BW_SESSION

    echo ""
    echo "==> Checking SSH key for GitHub..."
    SSH_KEY="${HOME}/.ssh/id_ed25519"
    if [[ ! -f "$SSH_KEY" ]]; then
        echo "No SSH key found. Generating one..."
        ssh-keygen -t ed25519 -C "$(git config user.email 2>/dev/null || echo '')" -N "" -f "$SSH_KEY"
    fi

    SSH_RESULT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 || true)
    if ! echo "$SSH_RESULT" | grep -q "successfully authenticated"; then
        echo ""
        echo "SSH key is not yet registered on GitHub. Add this public key at:"
        echo "  https://github.com/settings/ssh/new"
        echo ""
        cat "${SSH_KEY}.pub"
        echo ""
        read -rp "Press Enter once you've added the key to GitHub..."

        SSH_RESULT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 || true)
        if ! echo "$SSH_RESULT" | grep -q "successfully authenticated"; then
            echo "Error: SSH authentication to GitHub still failing. Check that the key was added correctly."
            exit 1
        fi
    fi
    echo "GitHub SSH authentication confirmed."

    echo ""
    echo "==> Applying dotfiles..."
    chezmoi init --apply git@github.com:johngrantdev/dotfiles.git

    echo ""
    echo "Done! Dotfiles applied."
    echo "To keep the vault unlocked in your current shell, run:"
    echo "  export BW_SESSION=\$(bw unlock --raw)"

# Randomize MAC address for the current Wi-Fi connection to improve privacy on public networks
[group('Network')]
randomize-mac:
    #!/usr/bin/env bash
    set -eou pipefail

    ACTIVE=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="802-11-wireless"{print $1; exit}')
    if [[ -z "$ACTIVE" ]]; then
        echo "No active Wi-Fi connection found."
        exit 1
    fi

    echo "==> Setting MAC randomization for: $ACTIVE"
    nmcli connection modify "$ACTIVE" wifi.cloned-mac-address random
    nmcli connection down "$ACTIVE"
    nmcli connection up "$ACTIVE"
    echo "Done. New MAC: $(ip link show wlan0 | awk '/ether/{print $2}')"

# Show system info
[group('System')]
system-info:
    fastfetch

# Boot into this device's BIOS/UEFI screen
[group('System')]
bios:
    #!/usr/bin/bash
    if [ ! -d /sys/firmware/efi ]; then
        echo "Rebooting to legacy BIOS from OS is not supported."
        exit 1
    fi

    if gum confirm "Reboot into BIOS?" ; then
        systemctl reboot --firmware-setup
    fi

# Show BIOS info
[group('System')]
bios-info:
    #!/usr/bin/bash
    sudo bash <<'EOF'
    echo "Manufacturer: $(dmidecode -s baseboard-manufacturer)"
    echo "Product Name: $(dmidecode -s baseboard-product-name)"
    echo "Version: $(dmidecode -s bios-version)"
    echo "Release Date: $(dmidecode -s bios-release-date)"
    EOF

# Measure idle power draw
[group('System')]
check-idle-power-draw:
    #!/usr/bin/bash
    sudo powerstat -a -r

# Update system and flatpaks
[group('System')]
update:
    #!/usr/bin/bash
    if systemctl cat -- uupd.timer &> /dev/null; then
        SERVICE="uupd.service"
    else
        SERVICE="rpm-ostreed-automatic.service"
    fi
    if systemctl is-active --quiet "$SERVICE"; then
        echo "Automatic updates are currently running, use \`journalctl -fexu $SERVICE\` to see logs"
        exit 1
    fi
    # bootc upgrade doesn't support local layered packages, so fall back to
    # rpm-ostree upgrade if LockLayering is off in /etc/rpm-ostreed.conf.
    if command -v rpm-ostree >/dev/null 2>&1 && [ -f /etc/rpm-ostreed.conf ] && \
        grep -qE '^[[:space:]]*LockLayering[[:space:]]*=[[:space:]]*true' /etc/rpm-ostreed.conf; then
        sudo bootc upgrade
    else
        rpm-ostree upgrade
    fi
    if flatpak remotes | grep -q system; then
        flatpak update -y
    fi
    if flatpak remotes | grep -q user; then
        flatpak update --user -y
    fi
