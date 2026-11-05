#!/usr/bin/env bash
# Install the pinned Trivy binary, verified against its published sha256, into
# $1 (default ~/.local/bin). CI and the local gate use the same version, so a
# scan gives the same answer everywhere.
set -euo pipefail

TRIVY_VERSION="0.76.1"
# sha256 of trivy_0.76.1_Linux-64bit.tar.gz from the release checksums.txt.
TRIVY_SHA256="c7cbe3137fb8a48a17574bede3dd6beb16742d1e9772929940fc90082c39d9c0"

dest="${1:-$HOME/.local/bin}"
mkdir -p "$dest"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

url="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
curl -fsSL -o "$tmp/trivy.tar.gz" "$url"
echo "${TRIVY_SHA256}  $tmp/trivy.tar.gz" | sha256sum -c -

tar -xzf "$tmp/trivy.tar.gz" -C "$tmp" trivy
install -m 0755 "$tmp/trivy" "$dest/trivy"
echo "Trivy ${TRIVY_VERSION} installed to $dest/trivy"
