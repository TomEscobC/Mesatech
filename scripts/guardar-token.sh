#!/usr/bin/env bash
# Guarda un access token en un archivo local (permisos 600) SIN mostrarlo en pantalla.
# Uso: bash scripts/guardar-token.sh admin|cliente|operador
# Pasos: en el frontend (con ese usuario) pulsa "Inspeccionar Claims JWT", copia el access token y pegalo aqui cuando lo pida.
ROL="${1:?uso: guardar-token.sh admin|cliente|operador}"
F="$HOME/.mesatech_tok_$ROL"
printf "Pega el access token de '%s' (no se vera) y pulsa Enter: " "$ROL"
read -rs T; echo
T="$(printf '%s' "$T" | tr -d '[:space:]"')"
case "$T" in eyJ*.*.*) ;; *) echo "No parece un JWT (debe empezar con eyJ y tener 3 partes). No se guardo."; exit 1;; esac
umask 077; printf '%s' "$T" > "$F"
echo "Guardado en $F ($(wc -c < "$F") caracteres). Expira en ~1 hora."
