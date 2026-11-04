#!/usr/bin/env bash
# Muestra, con título, la salida de los comandos que sirven de evidencia (todos de solo lectura).
# Uso: bash scripts/evidencias-terminal.sh <n>     (sin n: lista las secciones)
# Requiere: ~/Descargas/labsuser.pem y ~/.mesatech_secrets (no se imprimen contraseñas).
K=${KEY:-$HOME/Descargas/labsuser.pem}
A=3.234.33.87; B=18.206.171.225; C=3.90.203.34; CP=172.31.30.196
CAT=mesatech-rds-catalogo.cstbnwfayxx4.us-east-1.rds.amazonaws.com
SOL=mesatech-rds-solicitudes.cstbnwfayxx4.us-east-1.rds.amazonaws.com
set -a; . ~/.mesatech_secrets 2>/dev/null; set +a
S="ssh -i $K -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
t(){ printf '\n===== %s =====\n' "$1"; }
sql(){ { echo "$3"; echo "$4"; } | $S ubuntu@$1 "read -r P; MYSQL_PWD=\$P mysql -h $2 -u $5 $6 --table 2>&1 | grep -v 'Using a password'"; }
case "${1:-}" in
1) t "[EP2-18] EC2-C: Docker y Compose instalados"; $S ubuntu@$C 'hostname; . /etc/os-release; echo $PRETTY_NAME; docker --version; docker compose version';;
2) t "[EP2-31] EC2-C: compose.yaml (sin secretos)"; $S ubuntu@$C 'cd ~/rabbitmq && cat compose.yaml';;
3) t "[EP2-19 a EP2-23] EC2-C: validar, estado y logs"; $S ubuntu@$C 'cd ~/rabbitmq; echo "$ docker compose config --quiet"; docker compose config --quiet && echo "(valido, sin salida)"; echo "$ docker compose pull"; docker compose pull 2>&1 | tail -3; echo "$ docker compose up -d"; docker compose up -d 2>&1 | tail -3; echo "$ docker compose ps"; docker compose ps; echo "$ docker compose logs rabbitmq (arranque e importacion de definiciones)"; docker compose logs rabbitmq 2>&1 | grep -E "Importing|started TCP listener|Server startup complete|Time to start" | sed "s/\x1b\[[0-9;]*m//g" | cut -c1-140 | head -8';;
4) t "[EP2-24 y EP2-32] EC2-C: puertos 5672 y 15672 escuchando"; $S ubuntu@$C "ss -lnt | grep -E '5672|15672'; docker port rabbitmq";;
5) t "[EP2-25] RabbitMQ: usuarios y permisos en el vhost mesatech"; $S ubuntu@$C 'docker exec rabbitmq rabbitmqctl list_users --silent; docker exec rabbitmq rabbitmqctl list_permissions -p mesatech --silent';;
6) t "[EP2-26 a EP2-29 (version CLI)] RabbitMQ: vhost, exchange, cola y binding"; $S ubuntu@$C 'echo "vhosts:"; docker exec rabbitmq rabbitmqctl list_vhosts --silent; echo; echo "exchange:"; docker exec rabbitmq rabbitmqctl list_exchanges -p mesatech name type durable --silent | grep catalogo; echo; echo "cola:"; docker exec rabbitmq rabbitmqctl list_queues -p mesatech name durable messages_ready messages_unacknowledged consumers --silent; echo; echo "binding:"; docker exec rabbitmq rabbitmqctl list_bindings -p mesatech --silent | grep categoria';;
7) t "[EP2-14] EC2-A y EC2-B: Java 21"; for h in $A $B; do $S ubuntu@$h 'hostname -I | cut -d" " -f1; java -version 2>&1 | head -1'; done;;
8) t "[EP2-33 y EP2-34] EC2-A: servicios catalogo y BFF"; $S ubuntu@$A 'hostname -I | cut -d" " -f1; for s in catalogo bff; do systemctl status mesatech-$s --no-pager | sed -n "1,4p"; done; ss -lnt | grep -E ":8080|:8082"';;
9) t "[EP2-35] EC2-B: servicio solicitudes"; $S ubuntu@$B 'hostname -I | cut -d" " -f1; systemctl status mesatech-solicitudes --no-pager | sed -n "1,4p"; ss -lnt | grep :8081';;
10) t "[EP2-17 / P1] Red: lo permitido conecta y lo prohibido no";
  tcp(){ timeout 6 bash -c "echo > /dev/tcp/$1/$2" 2>/dev/null && echo ABIERTO || echo bloqueado; }
  printf 'mi PC -> EC2-C 15672 (solo mi IP):  %s\n' "$(tcp $C 15672)"; printf 'mi PC -> EC2-C 5672  (solo A y B):  %s\n' "$(tcp $C 5672)"
  chk='t(){ timeout 6 bash -c "echo > /dev/tcp/$1/$2" 2>/dev/null && echo ABIERTO || echo bloqueado; }'
  $S ubuntu@$A "$chk; echo \"EC2-A -> RabbitMQ 5672:    \$(t $CP 5672)\"; echo \"EC2-A -> RDS catalogo 3306:   \$(t $CAT 3306)\"; echo \"EC2-A -> RDS solicitudes 3306: \$(t $SOL 3306)\""
  $S ubuntu@$B "$chk; echo \"EC2-B -> RabbitMQ 5672:    \$(t $CP 5672)\"; echo \"EC2-B -> RDS solicitudes 3306: \$(t $SOL 3306)\"; echo \"EC2-B -> RDS catalogo 3306:   \$(t $CAT 3306)\"";;
11) t "[EP2-37] RDS Catalogo (desde EC2-A): tablas"; sql $A $CAT "$DB_CAT_APP" "SHOW TABLES; SELECT id,codigo,nombre FROM categorias ORDER BY id DESC LIMIT 5;" catalogo_app mesatech_catalogo_db;;
12) t "[EP2-38] RDS Solicitudes (desde EC2-B): tablas y copia de categorias"; sql $B $SOL "$DB_SOL_APP" "SHOW TABLES; SELECT categoria_id,nombre,event_id,fecha_recepcion FROM categoria_copia ORDER BY fecha_recepcion DESC LIMIT 5;" solicitudes_app mesatech_solicitudes_db;;
13) t "[P3 / P4] Cola de RabbitMQ y consumidor"; $S ubuntu@$C 'docker exec rabbitmq rabbitmqctl list_queues -p mesatech name messages_ready messages_unacknowledged consumers --silent'; $S ubuntu@$B 'sudo journalctl -u mesatech-solicitudes --no-pager -n 400 | grep -E "Evento recibido|Categoría guardada" | tail -4 | cut -c60-230';;
*) cat <<'MENU'
 1 Docker/Compose en EC2-C      (EP2-18)      8  Servicios en EC2-A     (EP2-33/34)
 2 compose.yaml sin secretos    (EP2-31)      9  Servicio en EC2-B      (EP2-35)
 3 config/ps/logs de RabbitMQ   (EP2-19..23)  10 Red permitida/bloqueada (EP2-17, P1)
 4 Puertos 5672/15672           (EP2-24/32)   11 RDS Catalogo: tablas   (EP2-37)
 5 Usuarios y permisos          (EP2-25/30)   12 RDS Solicitudes        (EP2-38)
 6 vhost/exchange/cola/binding  (EP2-26..29)  13 Cola y consumidor      (P3/P4)
 7 Java 21 en EC2-A y EC2-B     (EP2-14)
MENU
;;
esac
