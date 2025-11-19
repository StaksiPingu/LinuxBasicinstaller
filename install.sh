#!/bin/bash

SCRIPT_URL="https://raw.githubusercontent.com/StaksiPingu/LinuxBasicinstaller/main/freshdocker-install.sh"
SCRIPT_NAME="freshdocker-install.sh"

echo "🔽 Downloading Docker Manager installer..."

# Download
if command -v curl &> /dev/null; then
    curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_NAME"
elif command -v wget &> /dev/null; then
    wget -q "$SCRIPT_URL" -O "$SCRIPT_NAME"
else
    echo "❌ Error: Neither curl nor wget found!"
    exit 1
fi

chmod +x "$SCRIPT_NAME"

echo "🚀 Starting Docker Manager..."
./"$SCRIPT_NAME"
