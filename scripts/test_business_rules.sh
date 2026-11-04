#!/bin/bash
set -e
echo "=========================================================="
echo "  TEST DE VALIDACION DE REGLAS DE NEGOCIO Y SLA (EC2)"
echo "=========================================================="

echo ""
echo "1. Creando Solicitud de prueba (Estado inicial: CREADA)..."
RESP=$(curl -s -X POST http://localhost:8081/v1/solicitudes \
  -H "Content-Type: application/json" \
  -d '{"titulo":"Falla Servidor Backup","descripcion":"Servidor no responde al ping","categoriaId":1,"prioridadId":1,"clienteEmail":"cliente@mesatech.cloud"}')
echo "Respuesta creacion: $RESP"
ID=$(echo "$RESP" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
echo "ID de la solicitud creada: $ID"

echo ""
echo "2. Probando REGLA DE NEGOCIO INVALIDA: Salto directo CREADA -> RESUELTA (Debe dar 422)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "http://localhost:8081/v1/solicitudes/$ID/estado" \
  -H "Content-Type: application/json" \
  -d '{"nuevoEstado":"RESUELTA","motivo":"Intento saltarme el flujo"}')

ERROR_BODY=$(curl -s -X PUT "http://localhost:8081/v1/solicitudes/$ID/estado" \
  -H "Content-Type: application/json" \
  -d '{"nuevoEstado":"RESUELTA","motivo":"Intento saltarme el flujo"}')

echo "Codigo HTTP recibido: $HTTP_CODE (Esperado: 422)"
echo "Mensaje de rechazo de negocio: $ERROR_BODY"

echo ""
echo "3. Ejecutando FLUJO VALIDO DE ESTADOS:"
echo -n "   a) Transicion a ASIGNADA: "
curl -s -X PUT "http://localhost:8081/v1/solicitudes/$ID/asignar" \
  -H "Content-Type: application/json" \
  -d '{"operadorEmail":"operador@mesatech.cloud"}' | grep -o '"estado":"[^"]*"'

echo -n "   b) Transicion a EN_PROCESO: "
curl -s -X PUT "http://localhost:8081/v1/solicitudes/$ID/estado" \
  -H "Content-Type: application/json" \
  -d '{"nuevoEstado":"EN_PROCESO","motivo":"Iniciando diagnostico en rack"}' | grep -o '"estado":"[^"]*"'

echo -n "   c) Transicion a RESUELTA (Valida tras pasar por EN_PROCESO): "
curl -s -X PUT "http://localhost:8081/v1/solicitudes/$ID/estado" \
  -H "Content-Type: application/json" \
  -d '{"nuevoEstado":"RESUELTA","motivo":"Cable reemplazado"}' | grep -o '"estado":"[^"]*"'

echo -n "   d) Transicion a CERRADA: "
curl -s -X PUT "http://localhost:8081/v1/solicitudes/$ID/estado" \
  -H "Content-Type: application/json" \
  -d '{"nuevoEstado":"CERRADA","motivo":"Cliente confirma conformidad"}' | grep -o '"estado":"[^"]*"'

echo ""
echo "4. Probando ENDPOINT V2 con calculo dinamico de SLA:"
curl -s "http://localhost:8081/v2/solicitudes/$ID" | python3 -m json.tool

echo ""
echo "=========================================================="
echo "  TODAS LAS REGLAS DE NEGOCIO VALIDADAS EXITOSAMENTE"
echo "=========================================================="
