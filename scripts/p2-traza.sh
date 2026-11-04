#!/usr/bin/env bash
# Rastro de una categoria a traves del sistema (solo lectura): catalogo -> RabbitMQ -> consumidor -> RDS Solicitudes.
# Uso: bash scripts/p2-traza.sh <codigo-categoria> [ventana]   Ej: bash scripts/p2-traza.sh EP2-A "20 min ago"
COD="${1:?codigo de categoria, ej. EP2-A}"; DESDE="${2:-20 min ago}"
K=${KEY:-$HOME/Descargas/labsuser.pem}
A=3.234.33.87; B=100.59.199.41; C=3.80.48.82
CAT=mesatech-rds-catalogo.cstbnwfayxx4.us-east-1.rds.amazonaws.com
SOL=mesatech-rds-solicitudes.cstbnwfayxx4.us-east-1.rds.amazonaws.com
set -a; . ~/.mesatech_secrets; set +a
S="ssh -i $K -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
sql(){ { echo "$3"; echo "$4"; } | $S ubuntu@$1 "read -r P; MYSQL_PWD=\$P mysql -h $2 -u $5 $6 --table 2>&1 | grep -v 'Using a password'"; }
echo "===== [P2] Rastro de la categoria $COD ====="
echo; echo "1) RDS Catalogo (EC2-A): fila original"
sql $A $CAT "$DB_CAT_APP" "SELECT id AS categoria_id, codigo, nombre, fecha_creacion FROM categorias WHERE codigo='$COD';" catalogo_app mesatech_catalogo_db
echo; echo "2) Publicador (EC2-A): evento publicado y confirmado por RabbitMQ"
$S ubuntu@$A "sudo journalctl -u mesatech-catalogo --since '$DESDE' --no-pager | grep 'Evento publicado' | tail -3 | sed 's/.*Evento publicado/Evento publicado/' | cut -c1-170"
echo; echo "3) RabbitMQ (EC2-C): cola"
$S ubuntu@$C "docker exec rabbitmq rabbitmqctl list_queues -p mesatech name messages_ready messages_unacknowledged consumers --silent"
echo; echo "4) Consumidor (EC2-B): evento recibido y guardado"
$S ubuntu@$B "sudo journalctl -u mesatech-solicitudes --since '$DESDE' --no-pager | grep -E 'Evento recibido|Categoría guardada' | tail -4 | sed 's/.*CategoriaListener *: //' | cut -c1-170"
echo; echo "5) RDS Solicitudes (EC2-B): copia local (mismo categoria_id y event_id)"
sql $B $SOL "$DB_SOL_APP" "SELECT categoria_id, nombre, event_id, fecha_recepcion FROM categoria_copia ORDER BY fecha_recepcion DESC LIMIT 3;" solicitudes_app mesatech_solicitudes_db
