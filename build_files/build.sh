#!/bin/bash

set -ouex pipefail

FLAVOR="${FLAVOR:-common}"

[ -d "/ctx/files/common" ] && cp -rT /ctx/files/common "/"
[ -d "/ctx/files/${FLAVOR}" ] && cp -rT "/ctx/files/${FLAVOR}" "/"

[ -f "/ctx/common.sh" ] && /ctx/common.sh
[ -f "/ctx/${FLAVOR}.sh" ] && "/ctx/${FLAVOR}.sh"
