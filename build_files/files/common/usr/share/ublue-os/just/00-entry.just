set allow-duplicate-recipes := true
set ignore-comments := true

_default:
    #!/usr/bin/bash
    ujust --list --list-heading $'Available commands:\n' --list-prefix $' - '

import? "/usr/share/ublue-os/just/60-custom.just"
