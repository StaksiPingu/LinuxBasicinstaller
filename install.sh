#!/bin/bash

SCRIPT_URL="https://raw.githubusercontent.com/StaksiPingu/LinuxBasicinstaller/main/docker-manager-instal.sh"
SCRIPT_NAME="docker-manager-instal.sh"

echo "🔽 Downloading installer..."

# Download
if command -v curl &> /dev/null; then
    curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_NAME"
elif command -v wget &> /dev/null; then
    wget -q "$SCRIPT_URL" -O "$SCRIPT_NAME"
else
    echo "❌ Error: Neither curl nor wget found!"
    exit 1
fi

# Ausführbar machen
chmod +x "$SCRIPT_NAME"

# Ausführen
echo "🚀 Starting installer..."
./"$SCRIPT_NAME"

# Cleanup optional
# rm -f "$SCRIPT_NAME"
