#!/bin/bash

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Docker Installation Script v2.2     ║${NC}"
echo -e "${BLUE}║   Docker + Compose + Portainer         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Root-Check
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Bitte als root ausführen (sudo)${NC}"
    exit 1
fi

# Funktion für Ja/Nein Abfragen
ask_yes_no() {
    while true; do
        read -p "$1 (j/n): " yn
        case $yn in
            [Jj]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Bitte j oder n eingeben.";;
        esac
    done
}

# Funktion für Docker Installation
install_docker() {
    echo -e "\n${BLUE}🐳 Installiere Docker...${NC}"
    
    # Alte Versionen entfernen
    echo -e "${CYAN}→ Entferne alte Docker-Versionen...${NC}"
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null
    
    # Abhängigkeiten installieren
    echo -e "${CYAN}→ Installiere Abhängigkeiten...${NC}"
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Docker GPG Key
    echo -e "${CYAN}→ Füge Docker GPG Key hinzu...${NC}"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Repository hinzufügen
    echo -e "${CYAN}→ Füge Docker Repository hinzu...${NC}"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Docker installieren
    echo -e "${CYAN}→ Installiere Docker Engine...${NC}"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    
    # Docker starten
    echo -e "${CYAN}→ Starte Docker Service...${NC}"
    systemctl start docker
    systemctl enable docker
    
    # Benutzer zur Docker-Gruppe hinzufügen
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        echo -e "${GREEN}✅ Benutzer $SUDO_USER zur Docker-Gruppe hinzugefügt${NC}"
    fi
    
    # Version prüfen
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✅ Docker installiert: $DOCKER_VERSION${NC}"
}

# Funktion für Docker Compose Installation
install_compose() {
    echo -e "\n${BLUE}🔧 Installiere Docker Compose v2...${NC}"
    
    echo -e "${CYAN}→ Installiere Docker Compose Plugin...${NC}"
    apt-get update
    apt-get install -y docker-compose-plugin
    
    # Version prüfen
    COMPOSE_VERSION=$(docker compose version)
    echo -e "${GREEN}✅ Docker Compose installiert: $COMPOSE_VERSION${NC}"
}

# Funktion für Portainer Installation
install_portainer() {
    echo -e "\n${BLUE}🎯 Installiere Portainer CE (LTS)...${NC}"
    
    # Portainer Volume erstellen
    echo -e "${CYAN}→ Erstelle Portainer Volume...${NC}"
    docker volume create portainer_data 2>/dev/null
    
    # Alte Portainer Container stoppen und entfernen
    if docker ps -a | grep -q portainer; then
        echo -e "${CYAN}→ Entferne alten Portainer Container...${NC}"
        docker stop portainer 2>/dev/null
        docker rm portainer 2>/dev/null
    fi
    
    # Portainer starten (MIT LTS TAG)
    echo -e "${CYAN}→ Starte Portainer Container...${NC}"
    docker run -d \
        -p 8000:8000 \
        -p 9443:9443 \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:lts
    
    # Warten bis Portainer läuft
    echo -e "${YELLOW}⏳ Warte auf Portainer Start (10 Sekunden)...${NC}"
    sleep 10
    
    # Status prüfen
    if docker ps | grep -q portainer; then
        # IP-Adresse ermitteln
        IP=$(hostname -I | awk '{print $1}')
        
        echo -e "${GREEN}✅ Portainer erfolgreich installiert!${NC}"
        echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║         Portainer Zugriff:             ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
        echo -e "${CYAN}📱 HTTPS: ${GREEN}https://${IP}:9443${NC}"
        echo -e "${CYAN}📱 HTTP:  ${GREEN}http://${IP}:8000${NC}"
        echo -e "\n${YELLOW}⚠️  Wichtig:${NC}"
        echo -e "   1. Selbst-signiertes Zertifikat akzeptieren"
        echo -e "   2. Beim ersten Start Admin-Account erstellen"
        echo -e "   3. Username & Passwort festlegen (min. 12 Zeichen)\n"
    else
        echo -e "${RED}❌ Portainer konnte nicht gestartet werden${NC}"
        echo -e "${YELLOW}→ Logs anzeigen mit: ${CYAN}docker logs portainer${NC}"
    fi
}

# Hauptmenü mit ALLE Option
echo -e "${YELLOW}Was möchten Sie installieren?${NC}\n"

INSTALL_DOCKER=false
INSTALL_COMPOSE=false
INSTALL_PORTAINER=false

# Erste Frage: Alles installieren?
if ask_yes_no "⚡ ALLE Komponenten installieren (Docker + Compose + Portainer)?"; then
    INSTALL_DOCKER=true
    INSTALL_COMPOSE=true
    INSTALL_PORTAINER=true
    echo -e "${GREEN}✓ Alle Komponenten werden installiert${NC}\n"
else
    # Einzeln abfragen
    echo -e "${CYAN}→ Einzelne Auswahl:${NC}\n"
    
    if ask_yes_no "🐳 Docker installieren?"; then
        INSTALL_DOCKER=true
    fi

    if ask_yes_no "🔧 Docker Compose installieren?"; then
        INSTALL_COMPOSE=true
    fi

    if ask_yes_no "🎯 Portainer CE installieren?"; then
        INSTALL_PORTAINER=true
    fi
fi

# Prüfen ob überhaupt etwas ausgewählt wurde
if [ "$INSTALL_DOCKER" = false ] && [ "$INSTALL_COMPOSE" = false ] && [ "$INSTALL_PORTAINER" = false ]; then
    echo -e "\n${RED}❌ Keine Komponente ausgewählt. Installation abgebrochen.${NC}"
    exit 0
fi

# Zusammenfassung
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}     Installation wird gestartet      ${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
[ "$INSTALL_DOCKER" = true ] && echo -e "${GREEN}✓${NC} Docker Engine (neueste Version)"
[ "$INSTALL_COMPOSE" = true ] && echo -e "${GREEN}✓${NC} Docker Compose v2"
[ "$INSTALL_PORTAINER" = true ] && echo -e "${GREEN}✓${NC} Portainer CE LTS"
echo ""

if ! ask_yes_no "Fortfahren?"; then
    echo -e "${RED}❌ Installation abgebrochen${NC}"
    exit 0
fi

# Installationen durchführen
[ "$INSTALL_DOCKER" = true ] && install_docker
[ "$INSTALL_COMPOSE" = true ] && install_compose
[ "$INSTALL_PORTAINER" = true ] && install_portainer

# Abschlussmeldung
echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ Installation abgeschlossen!     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

if [ "$INSTALL_DOCKER" = true ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Docker Befehle:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${CYAN}docker ps${NC}                    - Laufende Container"
    echo -e "  ${CYAN}docker ps -a${NC}                 - Alle Container"
    echo -e "  ${CYAN}docker images${NC}                - Installierte Images"
    echo -e "  ${CYAN}docker stats${NC}                 - Ressourcen-Nutzung"
    echo -e "  ${CYAN}docker system df${NC}             - Speichernutzung"
    echo -e "  ${CYAN}docker system prune -a${NC}       - Cleanup (Vorsicht!)"
    echo -e ""
fi

if [ "$INSTALL_COMPOSE" = true ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Docker Compose Befehle:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${CYAN}docker compose up -d${NC}         - Starten (detached)"
    echo -e "  ${CYAN}docker compose down${NC}          - Stoppen & entfernen"
    echo -e "  ${CYAN}docker compose ps${NC}            - Status anzeigen"
    echo -e "  ${CYAN}docker compose logs -f${NC}       - Logs verfolgen"
    echo -e "  ${CYAN}docker compose pull${NC}          - Images aktualisieren"
    echo -e ""
fi

if [ "$INSTALL_PORTAINER" = true ]; then
    IP=$(hostname -I | awk '{print $1}')
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Portainer:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${MAGENTA}🌐 Web-Interface:${NC}"
    echo -e "     ${GREEN}https://${IP}:9443${NC}"
    echo -e ""
    echo -e "  ${MAGENTA}📝 Befehle:${NC}"
    echo -e "     ${CYAN}docker logs portainer${NC}        - Logs anzeigen"
    echo -e "     ${CYAN}docker restart portainer${NC}     - Neustart"
    echo -e "     ${CYAN}docker stop portainer${NC}        - Stoppen"
    echo -e "     ${CYAN}docker start portainer${NC}       - Starten"
    echo -e ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⚠️  WICHTIG:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   ${YELLOW}1.${NC} Für Docker-Berechtigungen ${BLUE}neu einloggen${NC} oder:"
echo -e "      ${CYAN}newgrp docker${NC}"
echo -e ""
echo -e "   ${YELLOW}2.${NC} Docker testen mit:"
echo -e "      ${CYAN}docker run hello-world${NC}"
echo -e ""

if [ "$INSTALL_PORTAINER" = true ]; then
    echo -e "   ${YELLOW}3.${NC} Portainer Admin erstellen:"
    echo -e "      - Browser: ${GREEN}https://${IP}:9443${NC}"
    echo -e "      - Zertifikatswarnung akzeptieren"
    echo -e "      - Admin-Account anlegen"
    echo -e ""
fi

echo -e "${GREEN}🎉 Viel Erfolg mit Docker!${NC}\n"
