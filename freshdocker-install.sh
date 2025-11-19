#!/bin/bash

# Farben für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
clear
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     Docker & Portainer Installation Script              ║"
echo "║     für Ubuntu 24.04 LTS                                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ❌ DIESE ZEILEN ENTFERNEN:
# # Prüfen ob als Root ausgeführt wird
# if [ "$EUID" -eq 0 ]; then 
#     echo -e "${RED}[ERROR] Bitte führen Sie dieses Script NICHT als root aus!${NC}"
#     echo -e "${YELLOW}[INFO] Führen Sie es als normaler Benutzer aus. Sudo wird bei Bedarf automatisch verwendet.${NC}"
#     exit 1
# fi

# Funktion: Docker installieren
install_docker() {
    echo -e "${GREEN}[INFO] Installiere Docker...${NC}"
    
    # Alte Versionen entfernen
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null
    
    # Abhängigkeiten installieren
    apt-get update
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Docker GPG Key hinzufügen
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Docker Repository hinzufügen
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Docker installieren
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    
    # Docker Dienst starten
    systemctl start docker
    systemctl enable docker
    
    echo -e "${GREEN}[SUCCESS] Docker erfolgreich installiert!${NC}"
    docker --version
}

# Funktion: Docker Compose installieren
install_docker_compose() {
    echo -e "${GREEN}[INFO] Installiere Docker Compose V2...${NC}"
    
    apt-get update
    apt-get install -y docker-compose-plugin
    
    echo -e "${GREEN}[SUCCESS] Docker Compose V2 erfolgreich installiert!${NC}"
    docker compose version
}

# Funktion: Portainer Agent installieren
install_portainer_agent() {
    echo -e "${GREEN}[INFO] Installiere Portainer Agent...${NC}"
    
    # Prüfen ob Docker läuft
    if ! systemctl is-active --quiet docker; then
        echo -e "${RED}[ERROR] Docker ist nicht aktiv. Bitte zuerst Docker installieren!${NC}"
        return 1
    fi
    
    # Portainer Agent Container starten
    docker run -d \
      -p 9001:9001 \
      --name portainer_agent \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /var/lib/docker/volumes:/var/lib/docker/volumes \
      portainer/agent:latest
    
    echo -e "${GREEN}[SUCCESS] Portainer Agent erfolgreich installiert!${NC}"
    echo -e "${YELLOW}[INFO] Portainer Agent läuft auf Port 9001${NC}"
}

# Funktion: Alles updaten
update_all() {
    echo -e "${GREEN}[INFO] Update aller Komponenten...${NC}"
    
    # System Update
    apt-get update
    apt-get upgrade -y
    
    # Docker Update
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}[INFO] Update Docker...${NC}"
        apt-get install -y --only-upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    
    # Portainer Agent Update
    if docker ps -a | grep -q portainer_agent; then
        echo -e "${GREEN}[INFO] Update Portainer Agent...${NC}"
        docker stop portainer_agent
        docker rm portainer_agent
        install_portainer_agent
    fi
    
    echo -e "${GREEN}[SUCCESS] Alle Komponenten wurden aktualisiert!${NC}"
}

# Funktion: Alles deinstallieren
uninstall_all() {
    echo -e "${RED}[WARNUNG] Diese Aktion wird Docker, Docker Compose und Portainer Agent entfernen!${NC}"
    read -p "Möchten Sie wirklich fortfahren? (ja/nein): " confirm
    
    if [ "$confirm" != "ja" ]; then
        echo -e "${YELLOW}[INFO] Deinstallation abgebrochen.${NC}"
        return
    fi
    
    # Portainer Agent entfernen
    if docker ps -a | grep -q portainer_agent; then
        echo -e "${GREEN}[INFO] Entferne Portainer Agent...${NC}"
        docker stop portainer_agent
        docker rm portainer_agent
        docker rmi portainer/agent:latest
    fi
    
    # Docker entfernen
    echo -e "${GREEN}[INFO] Entferne Docker...${NC}"
    apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm /etc/apt/sources.list.d/docker.list
    rm /etc/apt/keyrings/docker.gpg
    
    echo -e "${GREEN}[SUCCESS] Alle Komponenten wurden entfernt!${NC}"
}

# Funktion: Installationsmenü
installation_menu() {
    echo ""
    echo -e "${BLUE}=== Installationsoptionen ===${NC}"
    echo "1) Nur Docker"
    echo "2) Docker + Docker Compose"
    echo "3) Docker + Docker Compose + Portainer Agent (Alles)"
    echo "4) Zurück zum Hauptmenü"
    echo ""
    read -p "Ihre Auswahl [1-4]: " install_choice
    
    case $install_choice in
        1)
            install_docker
            ;;
        2)
            install_docker
            install_docker_compose
            ;;
        3)
            install_docker
            install_docker_compose
            install_portainer_agent
            ;;
        4)
            return
            ;;
        *)
            echo -e "${RED}[ERROR] Ungültige Auswahl!${NC}"
            installation_menu
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}[INFO] Installation abgeschlossen!${NC}"
}

# Hauptmenü
main_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}=== Hauptmenü ===${NC}"
        echo "1) Installation"
        echo "2) Update (alles aktualisieren)"
        echo "3) Deinstallation (alles entfernen)"
        echo "4) Nichts tun (Beenden)"
        echo ""
        read -p "Ihre Auswahl [1-4]: " choice
        
        case $choice in
            1)
                installation_menu
                ;;
            2)
                update_all
                ;;
            3)
                uninstall_all
                ;;
            4)
                echo -e "${GREEN}[INFO] Script wird beendet. Auf Wiedersehen!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[ERROR] Ungültige Auswahl! Bitte wählen Sie 1-4.${NC}"
                ;;
        esac
    done
}

# Script starten
main_menu
