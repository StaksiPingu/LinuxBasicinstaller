#!/bin/bash

# ===================================================
# Docker Manager Script (Install | Update | Uninstall)
# Supports: Docker 24, Compose v2, Portainer CE (LTS)
# ===================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root starten!"
  exit 1
fi

install_docker_portainer() {
  echo "=== Entferne alte Docker-Versionen ==="
  apt remove -y docker docker-engine docker.io containerd runc

  echo "=== Abhängigkeiten installieren ==="
  apt update
  apt install -y ca-certificates curl gnupg lsb-release

  echo "=== Docker GPG Key hinzufügen ==="
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo "=== Docker Repository einrichten ==="
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
    $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt update

  echo "=== Docker Engine 24 + Compose v2 installieren ==="
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo "=== Docker aktivieren ==="
  systemctl enable docker
  systemctl start docker

  echo "=== Benutzer zur docker-Gruppe hinzufügen ==="
  usermod -aG docker ${SUDO_USER:-$USER}

  echo "=== Volume für Portainer anlegen ==="
  docker volume create portainer_data >/dev/null

  echo "=== Starte Portainer CE LTS ==="
  docker stop portainer >/dev/null 2>&1
  docker rm portainer >/dev/null 2>&1

  docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:lts

  echo "=============================================="
  echo "INSTALLATION FERTIG!"
  echo "Portainer erreichbar unter:"
  echo "  https://<DEINE-IP>:9443"
  echo "=============================================="
}

update_docker_portainer() {
  echo "=== Docker aktualisieren ==="
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo "=== Docker neu starten ==="
  systemctl restart docker

  echo "=== Portainer aktualisieren ==="
  docker pull portainer/portainer-ce:lts

  docker stop portainer >/dev/null 2>&1
  docker rm portainer >/dev/null 2>&1

  docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:lts

  echo "=============================================="
  echo "UPDATE FERTIG!"
  echo "Docker & Portainer wurden aktualisiert."
  echo "=============================================="
}

uninstall_docker_portainer() {
  echo "=== Portainer stoppen ==="
  docker stop portainer 2>/dev/null
  docker rm portainer 2>/dev/null

  read -p "Portainer-Daten löschen? (j/n): " del
  if [[ "$del" == "j" || "$del" == "J" ]]; then
    docker volume rm portainer_data 2>/dev/null
  fi

  echo "=== Docker Pakete entfernen ==="
  apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io docker-engine runc

  echo "=== Datenverzeichnisse löschen ==="
  rm -rf /var/lib/docker
  rm -rf /var/lib/containerd

  echo "=== Docker Repository entfernen ==="
  rm -f /etc/apt/sources.list.d/docker.list
  rm -f /etc/apt/keyrings/docker.gpg
  apt update

  echo "=============================================="
  echo "Docker & Portainer wurden vollständig entfernt."
  echo "=============================================="
}

# ========================
# Hauptmenü
# ========================
while true; do
  clear
  echo "======================"
  echo "  DOCKER MANAGER"
  echo "======================"
  echo "1) Installieren"
  echo "2) Updaten"
  echo "3) Deinstallieren"
  echo "4) Beenden"
  echo ""
  read -p "Auswahl: " choice

  case $choice in
    1) install_docker_portainer ;;
    2) update_docker_portainer ;;
    3) uninstall_docker_portainer ;;
    4) echo "Tschüss!"; exit 0 ;;
    *) echo "Ungültige Eingabe!" ;;
  esac

  echo ""
  read -p "Weiter mit ENTER..."
done
