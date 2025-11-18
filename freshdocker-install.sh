#!/bin/bash

# ===========================================
# Docker + Compose + Portainer Setup (v3.0)
# Getestet auf: Ubuntu 20.04 / 22.04 / 24.04
# ===========================================

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
echo "║        Auto-Installation v3.0          ║"
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
            read -t 10 answer || true
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

# Kleine Hilfsfunktion: auf Docker warten
wait_for_docker() {
    echo -e "${YELLOW}→ Warte auf Docker-Daemon...${NC}"
    for i in {1..30}; do
        if docker info >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Docker-Daemon läuft.${NC}"
            return 0
        fi
        sleep 1
    done
    echo -e "${RED}❌ Docker-Daemon konnte nicht gestartet werden!${NC}"
    systemctl status docker --no-pager
    return 1
}

# ===========================================
# DOCKER INSTALLATION
# ===========================================
if $INSTALL_DOCKER; then
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        Docker Installation             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"

    # System Update
    echo -e "${YELLOW}→ Aktualisiere Paketquellen...${NC}"
    apt-get update -qq

    echo -e "${YELLOW}→ Optional: Systemupgrade (empfohlen)...${NC}"
    if ask_with_default "Jetzt 'apt-get upgrade -y' ausführen?" "j"; then
        apt-get upgrade -y -qq
    fi

    # Alte Docker-Versionen entfernen
    echo -e "${YELLOW}→ Entferne alte Docker-Versionen...${NC}"
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

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
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
    fi

    # Docker Repository
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo -e "${YELLOW}→ Füge Docker Repository hinzu...${NC}"
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    # Docker installieren
    echo -e "${YELLOW}→ Installiere Docker Engine + Plugins...${NC}"
    apt-get update -qq
    apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Docker-Gruppe + Benutzer
    echo -e "${YELLOW}→ Richte Docker-Gruppe ein...${NC}"
    groupadd -f docker
    usermod -aG docker "$REAL_USER"

    # Docker starten
    systemctl enable docker >/dev/null 2>&1
    systemctl restart docker

    if ! wait_for_docker; then
        echo -e "${RED}❌ Docker konnte nicht korrekt gestartet werden. Abbruch.${NC}"
        exit 1
    fi

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

    # Falls Docker noch nicht installiert wurde, Plugin über apt installieren
    echo -e "${YELLOW}→ Stelle sicher, dass Docker Compose Plugin installiert ist...${NC}"
    apt-get install -y -qq docker-compose-plugin || true

    # Pfad des Plugins ermitteln
    COMPOSE_PLUGIN_PATH=""
    for p in \
        /usr/libexec/docker/cli-plugins/docker-compose \
        /usr/lib/docker/cli-plugins/docker-compose \
        /usr/local/lib/docker/cli-plugins/docker-compose
    do
        if [ -x "$p" ]; then
            COMPOSE_PLUGIN_PATH="$p"
            break
        fi
    done

    if [ -z "$COMPOSE_PLUGIN_PATH" ]; then
        echo -e "${RED}❌ Konnte docker-compose Plugin nicht finden!${NC}"
        echo -e "${YELLOW}Bitte prüfe manuell: 'docker compose version'${NC}"
    else
        echo -e "${YELLOW}→ Erstelle Symlink für 'docker-compose' Befehl...${NC}"
        ln -sf "$COMPOSE_PLUGIN_PATH" /usr/local/bin/docker-compose
    fi

    # Version prüfen
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version | awk '{print $4}')
        echo -e "${GREEN}✅ Docker Compose installiert: ${COMPOSE_VERSION}${NC}"
    else
        echo -e "${RED}⚠️  'docker compose' konnte nicht ausgeführt werden.${NC}"
    fi
fi

# ===========================================
# PORTAINER INSTALLATION
# ===========================================
if $INSTALL_PORTAINER; then
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       Portainer CE Installation        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"

    # Sicherstellen, dass Docker läuft
    if ! systemctl is-active --quiet docker; then
        echo -e "${YELLOW}→ Docker läuft nicht, starte Service...${NC}"
        systemctl restart docker
    fi

    if ! wait_for_docker; then
        echo -e "${RED}❌ Ohne laufenden Docker-Daemon kann Portainer nicht installiert werden.${NC}"
        exit 1
    fi

    # Alte Portainer-Installation entfernen
    echo -e "${YELLOW}→ Entferne alte Portainer-Installation (falls vorhanden)...${NC}"
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    docker volume rm portainer_data 2>/dev/null || true

    # Volume erstellen
    echo -e "${YELLOW}→ Erstelle Portainer Volume...${NC}"
    docker volume create portainer_data >/dev/null

    # Image vorab ziehen (schnellere & zuverlässigere Starts)
    echo -e "${YELLOW}→ Lade Portainer Image (lts)...${NC}"
    docker pull portainer/portainer-ce:lts

    # Portainer starten
    echo -e "${YELLOW}→ Starte Portainer Container...${NC}"
    docker run -d \
      -p 8000:8000 \
      -p 9443:9443 \
      --name portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:lts >/dev/null

    # Warten bis Portainer gestartet ist
    echo -e "${YELLOW}⏳ Warte auf Portainer Start...${NC}"
    sleep 15

    # Status prüfen
    if docker ps --filter "name=portainer" --filter "status=running" --format '{{.Names}}' | grep -q "^portainer$"; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
        echo -e "${GREEN}✅ Portainer erfolgreich gestartet!${NC}"
        echo -e "${CYAN}🌐 Zugriff: https://${SERVER_IP}:9443${NC}"
        echo -e "${YELLOW}Wenn in der GUI 'local environment unreachable' steht:${NC}"
        echo -e "   → Unter 'Environments' prüfen, dass 'local' auf 'Docker socket' (unix:///var/run/docker.sock) gestellt ist."
    else
        echo -e "${RED}❌ Portainer konnte nicht gestartet werden!${NC}"
        echo -e "${YELLOW}Logs (letzte 20 Zeilen):${NC}"
        docker logs portainer 2>&1 | tail -20 || true
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
$INSTALL_DOCKER && echo -e "   • Docker Engine: $(docker --version | awk '{print $3}' | tr -d ',')"
$INSTALL_COMPOSE && docker compose version >/dev/null 2>&1 && \
    echo -e "   • Docker Compose: $(docker compose version | awk '{print $4}')"
$INSTALL_PORTAINER && echo -e "   • Portainer CE: https://${SERVER_IP}:9443"

echo -e "\n${YELLOW}⚠️  WICHTIG:${NC}"
echo -e "   1. ${CYAN}Melde dich neu an${NC} oder führe aus: ${BLUE}newgrp docker${NC}"
echo -e "   2. Dann teste: ${BLUE}docker ps${NC}"
if $INSTALL_PORTAINER; then
    echo -e "   3. Portainer Setup im Browser: ${BLUE}https://${SERVER_IP}:9443${NC}"
    echo -e "      → Beim ersten Login Admin-Account erstellen."
fi

echo -e "\n${GREEN}🎉 Installation abgeschlossen!${NC}\n"

# Hinweis für aktuellen Benutzer
if [[ "$REAL_USER" != "root" ]]; then
    echo -e "${CYAN}💡 Tipp: Führe jetzt aus als ${REAL_USER}:${NC}"
    echo -e "   ${BLUE}su - ${REAL_USER}${NC}"
    echo -e "   ${BLUE}docker ps${NC}\n"
fi
