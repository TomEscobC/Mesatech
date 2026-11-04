#!/usr/bin/env bash
# P7: fallo de publicacion con el broker detenido. Fases: detener | datos <codigo> [desde] | levantar
# Uso: bash scripts/p7-fallo.sh <fase>
K=${KEY:-$HOME/Descargas/labsuser.pem}
A=3.234.33.87; B=18.206.171.225; C=3.90.203.34
CAT=mesatech-rds-catalogo.cstbnwfayxx4.us-east-1.rds.amazonaws.com
SOL=mesatech-rds-solicitudes.cstbnwfayxx4.us-east-1.rds.amazonaws.com
set -a; . ~/.mesatech_secrets; set +a
S="ssh -i $K -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
sql(){ { echo "$3"; echo "$4"; } | $S ubuntu@$1 "read -r P; MYSQL_PWD=\$P mysql -h $2 -u $5 $6 --table 2>&1 | grep -v 'Using a password'"; }
case "${1:-}" in
detener)  echo "===== [P7] Detener RabbitMQ (EC2-C) ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
          $S ubuntu@$C 'cd ~/rabbitmq; echo "$ docker compose stop"; docker compose stop 2>&1 | tail -2; echo "$ docker compose ps"; docker compose ps 2>&1 | cut -c1-120; echo "$ ss -lnt | grep -E 5672  (nada escuchando)"; ss -lnt | grep -E ":5672 |:15672 " || echo "(sin puertos 5672/15672)"';;
datos)    COD="${2:?codigo}"; DESDE="${3:-10 min ago}"
          echo "===== [P7] Estado tras el fallo: categoria $COD ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
          echo "1) RDS Catalogo: la fila SI existe"
          sql $A $CAT "$DB_CAT_APP" "SELECT id AS categoria_id, codigo, nombre FROM categorias WHERE codigo='$COD';" catalogo_app mesatech_catalogo_db
          echo "2) Publicador (EC2-A): no se confirmo la publicacion"
          $S ubuntu@$A "sudo journalctl -u mesatech-catalogo --since '$DESDE' --no-pager | grep -iE 'Publicaci|Fallo al publicar|no confirm' | tail -3 | sed -E 's/^(.{15}).*(Publicaci|Fallo)/\1  \2/' | cut -c1-165"
          echo "3) RDS Solicitudes: la copia NO existe (0 filas)"
          sql $B $SOL "$DB_SOL_APP" "SELECT COUNT(*) AS copias_con_ese_nombre FROM categoria_copia WHERE nombre LIKE '%$COD%' OR nombre LIKE 'EP2 Categoria D%';" solicitudes_app mesatech_solicitudes_db;;
levantar) echo "===== [P7] Levantar RabbitMQ y comprobar reconexion ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
          $S ubuntu@$C 'cd ~/rabbitmq; echo "$ docker compose start"; docker compose start 2>&1 | tail -2
             for i in $(seq 1 30); do s=$(docker inspect rabbitmq -f "{{.State.Health.Status}}" 2>/dev/null); [ "$s" = healthy ] && break; sleep 3; done; echo "estado del broker: $s"
             echo "$ rabbitmqctl list_queues (cola, ready, unacked, consumidores)"; for i in $(seq 1 20); do q=$(docker exec rabbitmq rabbitmqctl list_queues -p mesatech name messages_ready messages_unacknowledged consumers --silent 2>/dev/null); echo "$q" | grep -q " 1$\|	1$" && break; sleep 3; done; echo "$q"';;
*) echo "uso: bash scripts/p7-fallo.sh detener | datos <codigo> [desde] | levantar";;
esac
