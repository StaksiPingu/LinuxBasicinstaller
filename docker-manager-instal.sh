#!/bin/bash

set -e

echo "Docker Manager Installer"
echo "========================="

TARGET="/usr/local/bin/docker-manager"
SOURCE_URL="https://raw.githubusercontent.com/StaksiPingu/LinuxBasicinstaller/main/freshdocker-install.sh"

echo "Lade docker-manager herunter..."
curl -sSL "$SOURCE_URL" -o "$TARGET"

chmod +x "$TARGET"

echo ""
echo "Installation abgeschlossen!"
echo "Starte das Menü jetzt mit:"
echo "sudo docker-manager"
echo ""
