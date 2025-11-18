#!/bin/bash

#=============================================================================
# Docker + Docker Compose + Portainer CE - Installer
# Unterstützt: Ubuntu, Debian, CentOS, Fedora
#=============================================================================

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "════════════════════════════════════════════════════════"
echo "   Docker Stack Installer"
echo "   Docker Engine + Docker Compose + Portainer CE"
echo "════════════════════════════════════════════════════════"
echo -e "${NC}"

# Funktion für Erfolgsmeldungen
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Funktion für Fehlermeldungen
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Funktion für Info-Meldungen
info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

# Root-Check
if [ "$EUID" -ne 0 ]; then 
    error "Bitte als Root ausführen (sudo)"
    exit 1
fi

# System-Detection
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        error "Betriebssystem nicht erkannt"
        exit 1
    fi
    info "Erkanntes System: $OS $VER"
}

#=============================================================================
# DOCKER INSTALLATION
#=============================================================================

install_docker() {
    echo ""
    info "Möchtest du Docker Engine installieren? (j/n)"
    read -r response
    
    if [[ "$response" =~ ^([jJ][aA]|[jJ])$ ]]; then
        info "Installiere Docker Engine..."
        
        # Alte Versionen entfernen
        if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
            apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null
            
            # Abhängigkeiten
            apt-get update
            apt-get install -y ca-certificates curl gnupg lsb-release
            
            # GPG Key
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            
            # Repository
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Installation
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            
        elif [ "$OS" = "centos" ] || [ "$OS" = "fedora" ] || [ "$OS" = "rhel" ]; then
            yum remove -y docker docker-client docker-client-latest docker-common docker-latest 2>/dev/null
            
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
        
        # Docker starten
        systemctl start docker
        systemctl enable docker
        
        # Testen
        if docker --version > /dev/null 2>&1; then
            success "Docker Engine installiert: $(docker --version)"
        else
            error "Docker Installation fehlgeschlagen"
            exit 1
        fi
        
        # Aktuellen User zur docker-Gruppe hinzufügen
        if [ -n "$SUDO_USER" ]; then
            info "Füge User '$SUDO_USER' zur docker-Gruppe hinzu..."
            usermod -aG docker $SUDO_USER
            success "User hinzugefügt (Neuanmeldung erforderlich)"
        fi
    else
        info "Docker Installation übersprungen"
    fi
}

#=============================================================================
# DOCKER COMPOSE CHECK
#=============================================================================

check_docker_compose() {
    echo ""
    info "Prüfe Docker Compose..."
    
    if docker compose version > /dev/null 2>&1; then
        success "Docker Compose bereits installiert: $(docker compose version)"
    else
        error "Docker Compose nicht gefunden (sollte mit Docker installiert sein)"
        info "Möchtest du es manuell installieren? (j/n)"
        read -r response
        
        if [[ "$response" =~ ^([jJ][aA]|[jJ])$ ]]; then
            if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
                apt-get update
                apt-get install -y docker-compose-plugin
            elif [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
                yum install -y docker-compose-plugin
            fi
            success "Docker Compose Plugin installiert"
        fi
    fi
}

#=============================================================================
# PORTAINER CE INSTALLATION
#=============================================================================

install_portainer() {
    echo ""
    info "Möchtest du Portainer CE installieren? (j/n)"
    read -r response
    
    if [[ "$response" =~ ^([jJ][aA]|[jJ])$ ]]; then
        info "Installiere Portainer CE..."
        
        # Volume erstellen
        docker volume create portainer_data
        
        # Port-Auswahl
        echo ""
        info "Auf welchem Port soll Portainer laufen? (Standard: 9443)"
        read -r portainer_port
        portainer_port=${portainer_port:-9443}
        
        # Portainer starten
        docker run -d \
            --name portainer \
            --restart=always \
            -p 8000:8000 \
            -p ${portainer_port}:9443 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data \
            portainer/portainer-ce:latest
        
        if [ $? -eq 0 ]; then
            success "Portainer CE installiert!"
            echo ""
            echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}Portainer CE läuft jetzt!${NC}"
            echo -e "${GREEN}URL: https://$(hostname -I | awk '{print $1}'):${portainer_port}${NC}"
            echo -e "${GREEN}Oder: https://localhost:${portainer_port}${NC}"
            echo ""
            echo -e "${YELLOW}Beim ersten Aufruf Admin-User erstellen!${NC}"
            echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
        else
            error "Portainer Installation fehlgeschlagen"
        fi
    else
        info "Portainer Installation übersprungen"
    fi
}

#=============================================================================
# ZUSAMMENFASSUNG
#=============================================================================

show_summary() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Installation abgeschlossen!${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if docker --version > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker Engine:${NC} $(docker --version)"
    fi
    
    if docker compose version > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker Compose:${NC} $(docker compose version --short)"
    fi
    
    if docker ps | grep -q portainer; then
        echo -e "${GREEN}✓ Portainer CE:${NC} Running"
    fi
    
    echo ""
    echo -e "${YELLOW}Nützliche Befehle:${NC}"
    echo "  docker --version              # Docker Version"
    echo "  docker compose version        # Compose Version"
    echo "  docker ps                     # Laufende Container"
    echo "  docker stats                  # Ressourcen-Monitor"
    echo ""
    
    if [ -n "$SUDO_USER" ]; then
        echo -e "${YELLOW}⚠ WICHTIG:${NC}"
        echo "  User '$SUDO_USER' muss sich neu anmelden,"
        echo "  um Docker ohne sudo nutzen zu können!"
        echo ""
    fi
}

#=============================================================================
# HAUPTPROGRAMM
#=============================================================================

main() {
    detect_os
    install_docker
    check_docker_compose
    install_portainer
    show_summary
}

# Script starten
main
