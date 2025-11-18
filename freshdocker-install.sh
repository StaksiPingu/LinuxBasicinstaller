#!/bin/bash

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
echo -e "${CYAN}"
echo "╔════════════════════════════════════════╗"
echo "║   Docker + Compose + Portainer Setup   ║"
echo "║        Auto-Installation v2.0          ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Root-Check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Dieses Script muss als root ausgeführt werden!${NC}"
   echo -e "${YELLOW}Führe aus: sudo $0${NC}"
   exit 1
fi

# Ursprünglicher Benutzer (nicht root)
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(eval echo ~$REAL_USER)

echo -e "${GREEN}✅ Starte Installation als: ${REAL_USER}${NC}\n"

# Funktion: Benutzer-Eingabe mit Timeout
ask_with_default() {
    local prompt="$1"
    local default="$2"
    local answer
    
    echo -e -n "${YELLOW}${prompt} [${default}]: ${NC}"
    
    # Timeout nach 10 Sekunden
    if read -t 10 answer; then
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
        
        # Validierung
        while [[ ! "$answer" =~ ^[jny]$ ]] && [[ -n "$answer" ]]; do
            echo -e "${RED}Ungültige Eingabe! Bitte j/n/y eingeben.${NC}"
            echo -e -n "${YELLOW}${prompt} [${default}]: ${NC}"
            read -t 10 answer
            answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
        done
        
        # Leere Eingabe = Standard
        [[ -z "$answer" ]] && answer="$default"
    else
        echo -e "\n${CYAN}⏱️  Timeout - verwende Standard: ${default}${NC}"
        answer="$default"
    fi
    
    [[ "$answer" == "j" ]] || [[ "$answer" == "y" ]]
}

# Abfragen
echo -e "${BLUE}═══ Installationsoptionen ═══${NC}\n"

if ask_with_default "Docker installieren?" "j"; then
    INSTALL_DOCKER=true
else
    INSTALL_DOCKER=false
fi

if ask_with_default "Docker Compose installieren?" "j"; then
    INSTALL_COMPOSE=true
else
    INSTALL_COMPOSE=false
fi

if ask_with_default "Portainer CE installieren?" "j"; then
    INSTALL_PORTAINER=true
else
    INSTALL_PORTAINER=false
fi

echo ""

# Nichts ausgewählt
if ! $INSTALL_DOCKER && ! $INSTALL_COMPOSE && ! $INSTALL_PORTAINER; then
    echo -e "${RED}❌ Keine Komponente ausgewählt. Installation abgebrochen.${NC}"
    exit 0
fi

# ===========================================
# DOCKER INSTALLATION
# ===========================================
if $INSTALL_DOCKER; then
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        Docker Installation             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
    
    # System Update
    echo -e "${YELLOW}→ Aktualisiere System...${NC}"
    apt-get update -qq
    apt-get upgrade -y -qq
    
    # Alte Docker-Versionen entfernen
    echo -e "${YELLOW}→ Entferne alte Docker-Versionen...${NC}"
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null
    
    # Dependencies
    echo -e "${YELLOW}→ Installiere Abhängigkeiten...${NC}"
    apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Docker GPG Key
    echo -e "${YELLOW}→ Füge Docker GPG Key hinzu...${NC}"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Docker Repository
    echo -e "${YELLOW}→ Füge Docker Repository hinzu...${NC}"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Docker installieren
    echo -e "${YELLOW}→ Installiere Docker Engine...${NC}"
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin
    
    # Docker starten
    systemctl start docker
    systemctl enable docker
    
    # Benutzer zur Docker-Gruppe hinzufügen
    echo -e "${YELLOW}→ Füge ${REAL_USER} zur Docker-Gruppe hinzu...${NC}"
    usermod -aG docker $REAL_USER
    
    # Socket-Berechtigungen setzen
    echo -e "${YELLOW}→ Setze Socket-Berechtigungen...${NC}"
    chmod 666 /var/run/docker.sock
    
    # Version prüfen
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✅ Docker installiert: ${DOCKER_VERSION}${NC}"
fi

# ===========================================
# DOCKER COMPOSE INSTALLATION
# ===========================================
if $INSTALL_COMPOSE; then
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      Docker Compose Installation       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}→ Installiere Docker Compose Plugin...${NC}"
    apt-get install -y -qq docker-compose-plugin
    
    # Symlink für 'docker-compose' Befehl
    if [ ! -L /usr/local/bin/docker-compose ]; then
        ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
    fi
    
    # Version prüfen
    COMPOSE_VERSION=$(docker compose version)
    echo -e "${GREEN}✅ Docker Compose installiert: ${COMPOSE_VERSION}${NC}"
fi

# ===========================================
# PORTAINER INSTALLATION
# ===========================================
if $INSTALL_PORTAINER; then
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       Portainer CE Installation        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"
    
    # Alte Portainer-Installation entfernen
    echo -e "${YELLOW}→ Entferne alte Portainer-Installation...${NC}"
    docker stop portainer 2>/dev/null
    docker rm portainer 2>/dev/null
    docker volume rm portainer_data 2>/dev/null
    
    # Volume erstellen
    echo -e "${YELLOW}→ Erstelle Portainer Volume...${NC}"
    docker volume create portainer_data
    
    # Socket-Berechtigungen sicherstellen
    chmod 666 /var/run/docker.sock
    
    # Portainer starten
    echo -e "${YELLOW}→ Starte Portainer Container...${NC}"
    docker run -d \
      -p 8000:8000 \
      -p 9443:9443 \
      --name portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:lts
    
    # Warten bis Portainer gestartet ist
    echo -e "${YELLOW}⏳ Warte auf Portainer Start...${NC}"
    sleep 15
    
    # Status prüfen
    if docker ps | grep -q portainer; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
        echo -e "${GREEN}✅ Portainer erfolgreich gestartet!${NC}"
        echo -e "${CYAN}🌐 Zugriff: https://${SERVER_IP}:9443${NC}"
    else
        echo -e "${RED}❌ Portainer konnte nicht gestartet werden!${NC}"
        echo -e "${YELLOW}Logs:${NC}"
        docker logs portainer 2>&1 | tail -20
    fi
fi

# ===========================================
# ZUSAMMENFASSUNG
# ===========================================
echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          Installation Abgeschlossen    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"

SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}✅ Installierte Komponenten:${NC}"
$INSTALL_DOCKER && echo -e "   • Docker Engine: $(docker --version | cut -d' ' -f3 | tr -d ',')"
$INSTALL_COMPOSE && echo -e "   • Docker Compose: $(docker compose version | cut -d' ' -f4)"
$INSTALL_PORTAINER && echo -e "   • Portainer CE: https://${SERVER_IP}:9443"

echo -e "\n${YELLOW}⚠️  WICHTIG:${NC}"
echo -e "   1. ${CYAN}Melde dich neu an${NC} oder führe aus: ${BLUE}newgrp docker${NC}"
echo -e "   2. Dann teste: ${BLUE}docker ps${NC}"
if $INSTALL_PORTAINER; then
    echo -e "   3. Portainer Setup: ${BLUE}https://${SERVER_IP}:9443${NC}"
    echo -e "      → Erstelle Admin-Account beim ersten Login"
fi

echo -e "\n${GREEN}🎉 Installation erfolgreich!${NC}\n"

# Hinweis für aktuellen Benutzer
if [[ "$REAL_USER" != "root" ]]; then
    echo -e "${CYAN}💡 Tipp: Führe jetzt aus als ${REAL_USER}:${NC}"
    echo -e "   ${BLUE}su - ${REAL_USER}${NC}"
    echo -e "   ${BLUE}docker ps${NC}\n"
fi
