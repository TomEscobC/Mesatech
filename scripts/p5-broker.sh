#!/usr/bin/env bash
# P5: reinicio del broker conservando volumen y hostname. Fases: antes | recrear | despues
# Uso: bash scripts/p5-broker.sh <fase>
K=${KEY:-$HOME/Descargas/labsuser.pem}; C=3.80.48.82
S="ssh -i $K -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR ubuntu@$C"
ESTADO='echo "$ docker volume ls | grep rabbitmq"; docker volume ls | grep rabbitmq
echo "$ docker inspect rabbitmq  (hostname, id corto, creado)"; docker inspect rabbitmq -f "hostname={{.Config.Hostname}}  id={{printf \"%.12s\" .Id}}  creado={{.Created}}"
echo "$ rabbitmqctl: vhost, exchange, cola"; docker exec rabbitmq rabbitmqctl list_vhosts --silent
docker exec rabbitmq rabbitmqctl list_exchanges -p mesatech name type durable --silent | grep catalogo
docker exec rabbitmq rabbitmqctl list_queues -p mesatech name durable messages_ready messages_unacknowledged consumers --silent
echo "$ rabbitmqctl list_bindings"; docker exec rabbitmq rabbitmqctl list_bindings -p mesatech --silent | grep categoria'
case "${1:-}" in
antes)   echo "===== [P5] ANTES de recrear el contenedor ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"; $S "$ESTADO";;
recrear) echo "===== [P5] Recrear el contenedor (sin borrar el volumen) ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
         $S 'cd ~/rabbitmq; echo "$ docker compose down   (sin -v: el volumen se conserva)"; docker compose down 2>&1 | tail -3
             echo "$ docker compose up -d --force-recreate"; docker compose up -d --force-recreate 2>&1 | tail -3
             echo "$ espera a que el broker quede healthy..."; for i in $(seq 1 30); do s=$(docker inspect rabbitmq -f "{{.State.Health.Status}}" 2>/dev/null); [ "$s" = healthy ] && break; sleep 3; done; echo "estado: $s"
             echo "$ docker compose ps"; docker compose ps 2>&1 | cut -c1-150';;
despues) echo "===== [P5] DESPUES de recrear el contenedor ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"; $S "$ESTADO";;
*) echo "uso: bash scripts/p5-broker.sh antes|recrear|despues";;
esac
