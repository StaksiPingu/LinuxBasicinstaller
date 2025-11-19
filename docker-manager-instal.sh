#!/bin/bash
# docker-portainer-installer.sh - Ubuntu 24.04 Noble Version

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

echo -e "${BLUE}=== Docker + Docker Compose V2 + Portainer Installer für Ubuntu 24.04 ===${NC}"

# System-Info anzeigen
UBUNTU_VERSION=$(lsb_release -cs)
UBUNTU_RELEASE=$(lsb_release -ds)
echo "💻 System: $UBUNTU_RELEASE"

# Prüfe Root-Rechte
if [ "$EUID" -ne 0 ]; then
    log_error "Bitte als root oder mit sudo ausführen"
    exit 1
fi

# Prüfe Ubuntu Version
if [ "$UBUNTU_VERSION" != "noble" ]; then
    log_warning "Dieses Script ist für Ubuntu 24.04 (Noble) optimiert"
    log_warning "Aktuelle Version: $UBUNTU_VERSION"
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

# Repository für NOBLE hinzufügen
log_info "Füge Docker Repository für Ubuntu Noble hinzu..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Aktuelle Docker Version installieren (für Noble)
log_info "Installiere Docker (aktuelle Version für Noble)..."
apt-get update

# Verfügbare Versionen prüfen
log_info "Verfügbare Docker-Versionen:"
apt-cache policy docker-ce | head -10

# Stabile Version installieren (ohne feste Versionsnummer)
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

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

# Prüfen ob Portainer bereits läuft
if docker ps -a | grep -q portainer; then
    log_info "Stoppe vorhandenen Portainer Container..."
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
fi

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
log_info "Warte auf Portainer Start..."
sleep 10

# Installation abschließen
log_success "=== Installation abgeschlossen! ==="
echo ""
echo "📊 Zugriff auf Portainer:"
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "   - HTTP:  http://$IP_ADDRESS:9000"
echo "   - HTTPS: https://$IP_ADDRESS:9443 (empfohlen)"
echo ""
echo "🔧 Installierte Versionen:"
docker --version
docker-compose --version
echo "Portainer: 2.33.2"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Browser öffnen: https://$IP_ADDRESS:9443"
echo "2. Admin-Passwort setzen"
echo "3. Lokale Umgebung auswählen"
echo ""
echo "⚠️  Wichtig: Nach Reboot neu einloggen oder 'newgrp docker' ausführen"

# Erfolgreich beenden
exit 0
