#!/usr/bin/env bash
# Crea los usuarios de aplicación con permisos mínimos sobre el vhost mesatech.
# Uso: PUB_PASS=... CONS_PASS=... ./create-users.sh
set -euo pipefail
: "${PUB_PASS:?definir PUB_PASS}" ; : "${CONS_PASS:?definir CONS_PASS}"
R="docker exec rabbitmq rabbitmqctl"
$R add_user mesatech_publicador "$PUB_PASS"
$R add_user mesatech_consumidor "$CONS_PASS"
$R set_permissions -p mesatech mesatech_publicador '^$' '^catalogo\.exchange$' '^$'
$R set_permissions -p mesatech mesatech_consumidor '^$' '^$' '^solicitudes\.catalogo\.queue$'
$R set_permissions -p mesatech mesatech_admin '.*' '.*' '.*' || true
$R list_users; $R list_permissions -p mesatech
