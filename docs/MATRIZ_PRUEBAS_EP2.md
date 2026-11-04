# Matriz de pruebas EP2 (P1–P8) y EP1 (9 pruebas)

Para cada prueba registrar: **preparación, datos usados, resultado esperado, resultado obtenido y evidencia** (código de captura).
Rellenar `<...>` con los valores reales. No mostrar contraseñas ni tokens completos en las capturas.

## Variables de trabajo (terminal de tu PC)
```bash
export API=https://<api-id>.execute-api.us-east-1.amazonaws.com
export TOKEN_ADMIN='<access token del admin>'      # ver "Cómo obtener el token"
export TOKEN_CLIENTE='<access token del cliente>'
export TOKEN_OPERADOR='<access token del operador>'
```
**Cómo obtener el token:** iniciar sesión en el frontend → botón "Inspeccionar Claims JWT" → copiar el token (es el access token de la API).
Caduca en ~1 h; repetir si aparece 401.

## Atajos que se usan en varias pruebas
```bash
# EC2-C (RabbitMQ): estado de la cola
docker exec rabbitmq rabbitmqctl list_queues -p mesatech name messages_ready messages_unacknowledged consumers
# EC2-A: última categoría en RDS Catálogo
mysql -h <endpoint-rds-catalogo> -u catalogo_app -p mesatech_catalogo_db -e "SELECT id,codigo,nombre FROM categorias ORDER BY id DESC LIMIT 3;"
# EC2-B: copias en RDS Solicitudes
mysql -h <endpoint-rds-solicitudes> -u solicitudes_app -p mesatech_solicitudes_db -e "SELECT categoria_id,nombre,event_id,fecha_recepcion FROM categoria_copia ORDER BY fecha_recepcion DESC LIMIT 3;"
# EC2-B: log del consumidor
journalctl -u mesatech-solicitudes --since "5 min ago" | grep -E "Evento recibido|Categoría guardada"
# EC2-A: log del publicador
journalctl -u mesatech-catalogo --since "5 min ago" | grep -E "Evento publicado|Publicación no confirmada|Fallo al publicar"
```
Crear categoría (reemplazar código y nombre; el código es único, máx. 30 caracteres):
```bash
curl -i -X POST "$API/v1/catalogo/categorias" -H "Authorization: Bearer $TOKEN_ADMIN" -H "Content-Type: application/json" \
  -d '{"codigo":"EP2-A","nombre":"EP2 Categoria A"}'
```
También puede crearse desde React con el usuario administrador (es lo que exige P2).

Categorías de prueba (nuevas, sin modificarlas después):
| Id de prueba | codigo | nombre | Se usa en |
|---|---|---|---|
| A | `EP2-A` | EP2 Categoria A | P2 |
| B | `EP2-B` | EP2 Categoria B | P3 y P4 |
| C | `EP2-C` | EP2 Categoria C | P5 |
| D | `EP2-D` | EP2 Categoria D | P7 |

---

## P1. Separación real
- **Preparación:** 3 EC2 y 2 RDS en ejecución.
- **Pasos:** consola EC2 → lista con Instance ID, nombre, IP privada y SG. Consola RDS → identificadores y endpoints. En cada EC2: `hostname -I`, `systemctl status mesatech-*` o `docker compose ps`.
- **Esperado:** A (catálogo + BFF), B (solicitudes) y C (RabbitMQ) con IDs distintos; dos endpoints RDS distintos; cada proceso asociado a su conexión y su tabla (`categorias` en RDS-Catálogo; `categoria_copia` en RDS-Solicitudes).
- **Prueba negativa:** desde EC2-A `mysql -h <endpoint-rds-solicitudes> -u solicitudes_app -p` debe agotar el tiempo (SG).
- **Evidencia:** EP2-12, EP2-09, EP2-15, EP2-16, EP2-17, y una tabla propia "proceso → EC2 → RDS → tabla".

## P2. Flujo completo (categoría A)
- **Pasos:**
  1. Crear categoría A desde React como administrador (captura de pantalla y de la respuesta 201 en la pestaña Network).
  2. EC2-A: log del publicador (`eventId`, `categoriaId`).
  3. RDS-Catálogo: fila `EP2-A`.
  4. EC2-B: log del consumidor con el mismo `eventId`.
  5. RDS-Solicitudes: fila en `categoria_copia` con el mismo `categoria_id`.
  6. En React (usuario cliente) pulsar "Actualizar", elegir la categoría A y crear una solicitud.
- **Esperado:** `categoriaId` coincide en las dos BD; el `eventId` del log del publicador aparece en el consumidor; la solicitud queda creada (201).
- **Evidencia:** EP2-40…EP2-46. Anotar la relación: solicitud HTTP → `categoriaId` → `eventId` → mensaje.
- **Contrato del evento (documentar un ejemplo real):**
```json
{"eventId":"<uuid>","tipoEvento":"CATEGORIA_CREADA","fechaEvento":"2026-11-04T20:05:31.123Z","categoriaId":<id>,"nombre":"EP2 Categoria A"}
```

## P3. Consumidor detenido (categoría B)
- **Preparación:** cola vacía (0/0).
- **Pasos:** EC2-B `sudo systemctl stop mesatech-solicitudes`; crear categoría B; ejecutar el atajo de la cola; consultar `categoria_copia` en RDS-Solicitudes; consultar RDS-Catálogo.
- **Esperado:** la categoría B está en RDS-Catálogo; `messages_ready = 1`, `consumers = 0`; **no** existe en `categoria_copia`.
- **Evidencia:** EP2-47…EP2-50.

## P4. Consumo diferido (categoría B)
- **Pasos:** EC2-B `sudo systemctl start mesatech-solicitudes`; esperar ~10 s; atajos de cola, log del consumidor y `categoria_copia`.
- **Esperado:** el mensaje de B se procesa; `categoria_copia` contiene B; `messages_ready = 0` y `messages_unacknowledged = 0`. Aclarar que la cola vacía por sí sola no demuestra persistencia: lo demuestra la fila en RDS.
- **Evidencia:** EP2-51…EP2-53.

## P5. Reinicio del broker (categoría C)
- **Pasos:**
  1. Detener el consumidor y crear la categoría C (cola con 1 mensaje).
  2. EC2-C: recrear el contenedor **sin borrar volúmenes**:
     ```bash
     cd ~/rabbitmq
     docker compose down            # NO usar -v
     docker compose up -d --force-recreate
     docker compose ps
     ```
  3. Comprobar que siguen el vhost, exchange, cola y mensaje (UI o `rabbitmqctl list_queues`, `list_exchanges -p mesatech`).
  4. Iniciar el consumidor y verificar `categoria_copia`.
- **Esperado:** `messages_ready = 1` tras el reinicio (mensaje persistente + cola durable + volumen); luego 0 y C en `categoria_copia`.
- **Precaución:** no usar "Get messages" con ack. Si se inspecciona desde la UI, elegir "Nack message requeue true" y dejarlo documentado.
- **Evidencia:** EP2-54…EP2-59 (incluir `docker volume ls` y el hostname del contenedor antes y después).

## P6. Reinicio de aplicaciones
- **Pasos:** `sudo systemctl restart mesatech-catalogo mesatech-bff` (EC2-A) y `sudo systemctl restart mesatech-solicitudes` (EC2-B); esperar el arranque; consultar `categorias` y `categoria_copia`.
- **Esperado:** siguen A, B y C en ambas BD; los servicios vuelven a conectarse al broker (log del consumidor).
- **Evidencia:** EP2-60…EP2-62.

## P7. Fallo de publicación (categoría D)
- **Pasos:**
  1. EC2-C: `docker compose stop`.
  2. Crear categoría D (React o `curl -i`).
  3. Capturar la respuesta (esperado **503** con mensaje "pudo quedar guardada… no se confirmó su publicación", más `categoriaId` y `eventId`).
  4. Consultar RDS-Catálogo: la fila `EP2-D` **existe**; `categoria_copia` no la tiene.
  5. `docker compose start`; confirmar que catálogo y consumidor se reconectan; crear otra categoría y comprobar que llega.
- **Explicación a incluir (sin afirmar recuperación automática):** el guardado en RDS y la publicación son operaciones separadas. Si la primera tiene éxito y la segunda falla, queda una categoría en Catálogo sin copia en Solicitudes, y el sistema no la reenvía solo. Reenviar la solicitud crearía un duplicado (código único → 409) y reentregar un mensaje puede duplicar el procesamiento; aquí el consumidor guarda con `categoria_id` como clave, por lo que una reentrega del mismo `categoriaId` no duplica filas. No se garantiza procesamiento exactamente una vez.
- **Evidencia:** EP2-63…EP2-68.

## P8. Continuidad de EP1
| # | Prueba | Comando / acción | Esperado |
|---|---|---|---|
| 8.1 | Login y consumo autorizado | Login en React; listar solicitudes | 200 y datos según rol |
| 8.2 | Sin token | `curl -i $API/v1/solicitudes` | **401** (lo rechaza API Gateway) |
| 8.3 | Token inválido | `curl -i -H "Authorization: Bearer abc.def.ghi" $API/v1/solicitudes` | **401** |
| 8.4 | Permisos insuficientes | `curl -i -X POST $API/v1/catalogo/categorias -H "Authorization: Bearer $TOKEN_CLIENTE" -H "Content-Type: application/json" -d '{"codigo":"X","nombre":"X"}'` | **403** (lo rechaza el BFF) |
| 8.5 | Regla EN_PROCESO | Crear solicitud (queda CREADA) y `curl -i -X PUT $API/v1/solicitudes/<id>/estado -H "Authorization: Bearer $TOKEN_OPERADOR" -H "Content-Type: application/json" -d '{"nuevoEstado":"RESUELTA","usuario":"<operador>"}'` | **422** |
| 8.6 | v1 y v2 | `curl -i -H "Authorization: Bearer $TOKEN_ADMIN" $API/v1/solicitudes` y `$API/v2/solicitudes` | 200 en ambas; v2 trae historial y siguientes estados |
| 8.7 | Categoría recibida utilizable | Crear solicitud con la categoría A desde React | 201, categoría = A |
- **Evidencia:** EP2-69…EP2-76.

---

## Matriz EP1 (las 9 pruebas, una sola versión para informe y presentación)
| # | Prueba | Esperado | Evidencia |
|---|---|---|---|
| PR-01 | Acceso sin autenticación (React sin sesión) | No se pueden cargar datos; se muestra la pantalla de login | EP1-20 |
| PR-02 | Solicitud a API Gateway sin token | 401 | EP1-21 |
| PR-03 | JWT inválido o expirado | 401 | EP1-22 |
| PR-04 | JWT válido y permisos suficientes | 200 / 201 | EP1-23 |
| PR-05 | Cliente intenta crear categoría | 403 (respuesta real contra la API, no solo test) | EP1-24 |
| PR-06 | CORS desde `http://localhost:3000` | El navegador permite el consumo (sin error CORS en consola) | EP1-25 |
| PR-07 | `RESUELTA` sin `EN_PROCESO` | 422 | EP1-26 |
| PR-08 | v1 y v2 coexisten | Ambas responden con su contrato | EP1-27 |
| PR-09 | Persistencia tras reiniciar servicios | Los datos siguen en RDS | EP1-28 |

## Resumen de resultados (completar durante la ejecución)
| Prueba | Fecha/hora | Resultado | Observaciones | Capturas |
|---|---|---|---|---|
| P1 | | | | |
| P2 | | | | |
| P3 | | | | |
| P4 | | | | |
| P5 | | | | |
| P6 | | | | |
| P7 | | | | |
| P8 | | | | |
