#!/usr/bin/env bash
# Crea los usuarios de aplicación con permisos mínimos sobre el vhost mesatech.
# Uso: PUB_PASS=... CONS_PASS=... ./create-users.sh   (lee RABBITMQ_ADMIN_* de ./.env)
set -euo pipefail
: "${PUB_PASS:?definir PUB_PASS}" ; : "${CONS_PASS:?definir CONS_PASS}"
set -a; . ./.env; set +a
R="docker exec rabbitmq rabbitmqctl"

# El usuario administrador se asegura aquí por si la importación de definiciones no lo creó
if ! $R list_users | grep -q "^${RABBITMQ_ADMIN_USER}\b"; then
  $R add_user "$RABBITMQ_ADMIN_USER" "$RABBITMQ_ADMIN_PASSWORD"
fi
$R set_user_tags "$RABBITMQ_ADMIN_USER" administrator
$R set_permissions -p mesatech "$RABBITMQ_ADMIN_USER" '.*' '.*' '.*'

$R add_user mesatech_publicador "$PUB_PASS"
$R add_user mesatech_consumidor "$CONS_PASS"
# Sin tags: no son administradores
$R set_permissions -p mesatech mesatech_publicador '^$' '^catalogo\.exchange$' '^$'
$R set_permissions -p mesatech mesatech_consumidor '^$' '^$' '^solicitudes\.catalogo\.queue$'
$R list_users; $R list_permissions -p mesatech
