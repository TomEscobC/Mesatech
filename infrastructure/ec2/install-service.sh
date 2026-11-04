#!/usr/bin/env bash
# Instala un microservicio como servicio systemd.
# Uso: sudo ./install-service.sh <nombre> <ruta-jar> <puerto>
#  Ej: sudo ./install-service.sh catalogo /opt/mesatech/mesatech-catalogo-1.0.0.jar 8082
# Las variables (DB_*, RABBITMQ_*, AZURE_*...) se leen de /etc/mesatech/<nombre>.env (fuera del repositorio, chmod 600).
set -euo pipefail
NAME="${1:?nombre}"; JAR="${2:?jar}"; PORT="${3:?puerto}"
ENVFILE="/etc/mesatech/${NAME}.env"
[ -f "$ENVFILE" ] || { echo "Falta $ENVFILE (copiar desde .env.example y completar)"; exit 1; }
chmod 600 "$ENVFILE"
cat > /etc/systemd/system/mesatech-${NAME}.service <<UNIT
[Unit]
Description=MesaTech ${NAME}
After=network-online.target
Wants=network-online.target

[Service]
User=ubuntu
EnvironmentFile=${ENVFILE}
ExecStart=/usr/bin/java -Xms128m -Xmx384m -Dserver.port=${PORT} -jar ${JAR}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now mesatech-${NAME}
sleep 5
systemctl status mesatech-${NAME} --no-pager | head -15
