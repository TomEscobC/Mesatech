#!/usr/bin/env bash
# P6: reinicio de las aplicaciones (catalogo, BFF, solicitudes). Fases: antes | reiniciar | despues
# Uso: bash scripts/p6-reinicio.sh <fase>
K=${KEY:-$HOME/Descargas/labsuser.pem}
A=3.234.33.87; B=18.206.171.225
CAT=mesatech-rds-catalogo.cstbnwfayxx4.us-east-1.rds.amazonaws.com
SOL=mesatech-rds-solicitudes.cstbnwfayxx4.us-east-1.rds.amazonaws.com
set -a; . ~/.mesatech_secrets; set +a
S="ssh -i $K -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
sql(){ { echo "$3"; echo "$4"; } | $S ubuntu@$1 "read -r P; MYSQL_PWD=\$P mysql -h $2 -u $5 $6 ${MODO:---table} 2>&1 | grep -v 'Using a password'"; }
inicio(){ $S ubuntu@$1 'for s in '"$2"'; do printf "%-20s activo desde: " mesatech-$s; systemctl show mesatech-$s -p ActiveEnterTimestamp --value; done'; }
datos(){
  echo "RDS Catalogo (EC2-A):"
  MODO="-N -B" sql $A $CAT "$DB_CAT_APP" "SELECT CONCAT('categorias en total: ',COUNT(*)) FROM categorias;" catalogo_app mesatech_catalogo_db
  sql $A $CAT "$DB_CAT_APP" "SELECT id,codigo,nombre FROM categorias WHERE codigo LIKE 'EP2-%' ORDER BY id;" catalogo_app mesatech_catalogo_db
  echo "RDS Solicitudes (EC2-B):"
  MODO="-N -B" sql $B $SOL "$DB_SOL_APP" "SELECT CONCAT('solicitudes en total: ',COUNT(*)) FROM solicitudes;" solicitudes_app mesatech_solicitudes_db
  sql $B $SOL "$DB_SOL_APP" "SELECT categoria_id,nombre,event_id FROM categoria_copia WHERE nombre LIKE 'EP2%' ORDER BY categoria_id;" solicitudes_app mesatech_solicitudes_db
}
case "${1:-}" in
antes)     echo "===== [P6] ANTES de reiniciar ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
           echo; echo "EC2-A:"; inicio $A "catalogo bff"; echo "EC2-B:"; inicio $B "solicitudes"; datos;;
reiniciar) echo "===== [P6] Reinicio de las aplicaciones ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
           echo; echo '$ EC2-A: sudo systemctl restart mesatech-catalogo mesatech-bff'; $S ubuntu@$A 'sudo systemctl restart mesatech-catalogo mesatech-bff && echo "(reiniciados)"'
           echo '$ EC2-B: sudo systemctl restart mesatech-solicitudes'; $S ubuntu@$B 'sudo systemctl restart mesatech-solicitudes && echo "(reiniciado)"'
           echo; echo "Esperando el arranque..."
           for i in $(seq 1 40); do
             a=$($S ubuntu@$A 'ss -lnt | grep -cE ":8080 |:8082 "' 2>/dev/null)
             b=$($S ubuntu@$B 'ss -lnt | grep -c ":8081 "' 2>/dev/null)
             [ "$a" = "2" ] && [ "$b" = "1" ] && break; sleep 3
           done
           echo; echo "Puertos escuchando en EC2-A (8080 BFF, 8082 catalogo):"; $S ubuntu@$A 'ss -lnt | grep -E ":8080 |:8082 " | awk "{print \$4}"'
           echo "Puerto escuchando en EC2-B (8081 solicitudes):"; $S ubuntu@$B 'ss -lnt | grep ":8081 " | awk "{print \$4}"';;
despues)   echo "===== [P6] DESPUES de reiniciar ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
           inicio $A "catalogo bff"; inicio $B "solicitudes"; datos
           echo "Consumidor (EC2-B): reconexion a RabbitMQ"
           $S ubuntu@$B "sudo journalctl -u mesatech-solicitudes --since '10 min ago' --no-pager | grep 'Created new connection' | tail -2 | sed -E 's/^(.{15}).*CachingConnectionFactory *: /\\1  /' | cut -c1-98"
           echo "Cola (EC2-C): cola, ready, unacked, consumidores"
           $S ubuntu@3.90.203.34 "docker exec rabbitmq rabbitmqctl list_queues -p mesatech name messages_ready messages_unacknowledged consumers --silent";;
*) echo "uso: bash scripts/p6-reinicio.sh antes|reiniciar|despues";;
esac
