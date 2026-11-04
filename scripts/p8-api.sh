#!/usr/bin/env bash
# P8: continuidad de EP1 contra API Gateway. Fases: sin-token | token-invalido | cliente-403 | estados | v1v2
# Los tokens se leen de ~/.mesatech_tok_<rol> (ver guardar-token.sh) y nunca se imprimen.
API=${API:-https://gpxa7yhvy2.execute-api.us-east-1.amazonaws.com}
tok(){ cat "$HOME/.mesatech_tok_$1" 2>/dev/null || { echo "falta token de $1: bash scripts/guardar-token.sh $1" >&2; exit 2; }; }
show(){ # metodo ruta token [json]
  local m=$1 r=$2 t=$3 d=$4
  local args=(-s -i -m 20 -X "$m" "$API$r" -H "Content-Type: application/json")
  [ -n "$t" ] && args+=(-H "Authorization: Bearer $t"); [ -n "$d" ] && args+=(-d "$d")
  curl "${args[@]}" | tr -d '\r' | grep -vi "^\(apigw-requestid\|x-content\|cache-control\|x-frame\|x-xss\|pragma\|expires\|strict-transport\|vary\|date\|connection\)" | cut -c1-230
}
case "${1:-}" in
sin-token)       echo "===== [P8.2] Sin token: lo rechaza API Gateway ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
                 echo '$ curl -i $API/v1/solicitudes'; show GET /v1/solicitudes "";;
token-invalido)  echo "===== [P8.3] Token invalido: lo rechaza API Gateway ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
                 echo '$ curl -i -H "Authorization: Bearer abc.def.ghi" $API/v1/solicitudes'; show GET /v1/solicitudes "abc.def.ghi";;
cliente-403)     echo "===== [P8.4] Cliente intenta crear categoria: lo rechaza el BFF ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
                 echo '$ curl -i -X POST $API/v1/catalogo/categorias -H "Authorization: Bearer $TOKEN_CLIENTE" -d {...}'
                 show POST /v1/catalogo/categorias "$(tok cliente)" '{"codigo":"X","nombre":"X"}';;
estados)         T="$(tok ${ROL:-admin})"; echo "===== [P8.5] Regla de estados: RESUELTA sin pasar por EN_PROCESO ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
                 echo '$ POST /v1/solicitudes  (categoriaId=7, queda CREADA)'
                 R=$(curl -s -X POST "$API/v1/solicitudes" -H "Authorization: Bearer $T" -H "Content-Type: application/json" -d '{"titulo":"Prueba regla de estados P8","descripcion":"Solicitud creada para verificar la regla EN_PROCESO","categoriaId":7,"prioridad":"Media","usuarioSolicitante":"admin@dsy1107seccion001dci.onmicrosoft.com"}')
                 ID=$(echo "$R" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])' 2>/dev/null); echo "$R" | cut -c1-200; echo "id creado: $ID"
                 echo '$ PUT /v1/solicitudes/'$ID'/estado  {"nuevoEstado":"RESUELTA"}'
                 show PUT /v1/solicitudes/$ID/estado "$T" '{"nuevoEstado":"RESUELTA","usuario":"admin"}';;
v1v2)            T="$(tok ${ROL:-admin})"; echo "===== [P8.6] v1 y v2 coexisten ====="; date -u +"%Y-%m-%d %H:%M:%S UTC"
                 for v in v1 v2; do echo "\$ curl -s $API/$v/solicitudes?size=1  (primer objeto)"
                   curl -s "$API/$v/solicitudes" -H "Authorization: Bearer $T" -o /tmp/p8_$v.json -w "HTTP %{http_code}\n"
                   python3 -c 'import json,sys; d=json.load(open("/tmp/p8_'$v'.json")); d=d[0] if isinstance(d,list) else d.get("content",[d])[0]; print("campos:",", ".join(d.keys()))' | cut -c1-220; rm -f /tmp/p8_$v.json; done;;
*) echo "uso: bash scripts/p8-api.sh sin-token | token-invalido | cliente-403 | estados | v1v2";;
esac
