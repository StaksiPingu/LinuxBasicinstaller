#!/bin/bash
# docker-portainer-installer.sh

set -e

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}=== Docker 28.5.1 + Docker Compose V2 + Portainer Installer ===${NC}"

# Prüfe Root-Rechte
if [ "$EUID" -ne 0 ]; then
    log_error "Bitte als root oder mit sudo ausführen"
    exit 1
fi

# Alte Versionen entfernen
log_info "Entferne alte Docker-Versionen..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Erforderliche Pakete installieren
log_info "Installiere benötigte Pakete..."
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Docker GPG Key hinzufügen
log_info "Füge Docker GPG Key hinzu..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Repository hinzufügen
log_info "Füge Docker Repository hinzu..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker 28.5.1 installieren
log_info "Installiere Docker 28.5.1..."
apt-get update
apt-get install -y \
    docker-ce=5:28.5.1-1~ubuntu.22.04~jammy \
    docker-ce-cli=5:28.5.1-1~ubuntu.22.04~jammy \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Version festhalten (verhindert unerwünschte Updates)
log_info "Halte Docker-Version fest..."
apt-mark hold docker-ce docker-ce-cli

# Docker Service starten
log_info "Starte Docker Service..."
systemctl enable docker
systemctl start docker

# Docker Compose Symlink erstellen (für V2)
log_info "Erstelle Docker Compose V2 Symlink..."
ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose 2>/dev/null || true

# Benutzer zur Docker Gruppe hinzufügen
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    log_info "Füge $SUDO_USER zur Docker Gruppe hinzu..."
    usermod -aG docker $SUDO_USER
fi

# Portainer installieren
log_info "Installiere Portainer 2.33.2..."
docker pull portainer/portainer-ce:2.33.2

# Portainer Container erstellen
log_info "Starte Portainer Container..."
docker run -d \
    --name portainer \
    -p 8000:8000 \
    -p 9000:9000 \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    --restart=unless-stopped \
    portainer/portainer-ce:2.33.2

# Warten bis Portainer läuft
sleep 5

# Installation abschließen
log_success "=== Installation abgeschlossen! ==="
echo ""
echo "📊 Zugriff auf Portainer:"
echo "   - HTTP:  http://$(hostname -I | awk '{print $1}'):9000"
echo "   - HTTPS: https://$(hostname -I | awk '{print $1}'):9443"
echo ""
echo "🔧 Versions-Info:"
docker --version
docker-compose --version
echo "Portainer: 2.33.2"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Browser öffnen: https://$(hostname -I | awk '{print $1}'):9443"
echo "2. Admin-Passwort setzen"
echo "3. Lokale Umgebung auswählen"

# Script ausführbar machen: chmod +x docker-portainer-installer.sh
# Ausführen: sudo ./docker-portainer-installer.sh
