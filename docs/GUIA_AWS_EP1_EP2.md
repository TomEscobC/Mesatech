# Guía paso a paso AWS: EP1 rehecho y EP2 (MesaTech Cloud)

Convención de capturas: guardar en `evidencias/` como `EP1-xx.png` / `EP2-xx.png` (📸 = captura). Una captura por paso, sin contraseñas ni
secretos en pantalla, con pie de figura "Figura N: qué prueba / qué requisito cubre".
Entorno: AWS Academy Learner Lab (región **us-east-1**, VPC por defecto, key pair `vockey`). Las IPs públicas cambian al detener el laboratorio;
entre servicios se usan **IPs privadas** y para el BFF una **Elastic IP**.

## Ajustes respecto a los apuntes de clase (leer antes de empezar)
Los apuntes de clase (14/08 API Gateway, 02/09 React + login, 30/09 RabbitMQ, 07/10 EC2 + RDS, 19/10 publicador) sirven como guía de **clics**, pero para
EP2 hay cosas que en clase se hicieron de forma abierta y la pauta **no las acepta**. Seguir esta guía donde difiera:
| Tema | En los apuntes | En EP2 / esta guía | Por qué |
|---|---|---|---|
| RDS | "Acceso público = Sí" y regla MySQL desde `0.0.0.0/0`, conectando con Workbench desde el PC | **Acceso público = No**; 3306 solo desde el SG de la EC2 dueña; consultas desde esa EC2 | C4 y C2: "no habilitar acceso mundial a RDS" |
| RabbitMQ | usuario `guest/guest`, 5672 y 15672 abiertos a `0.0.0.0/0`, imagen `rabbitmq:4.0-management` | usuarios propios (`create-users.sh`), 5672 solo desde SG de A y B, 15672 solo desde tu IP `/32`, etiqueta explícita `4.0.9-management`, hostname fijo y `restart: unless-stopped` | C3, C4, C5: no usar guest remoto, no abrir al mundo, imagen con etiqueta explícita |
| Permisos del usuario publicador | `.*` `.*` `.*` en el vhost | publicador solo escribe en `catalogo.exchange`; consumidor solo lee su cola | "no asignar privilegios administrativos a los usuarios de aplicación" |
| Credenciales | contraseñas escritas en `application.properties` y en los apuntes | variables de entorno (`/etc/mesatech/*.env`), nunca en el repo | entregable: sin secretos |
| Nombres | `ventas.exchange`, `ventas.queue`, `ventas.creada`, vhost `ventas` | `catalogo.exchange`, `solicitudes.catalogo.queue`, `categoria.creada`, vhost `mesatech` | "copiar el ejemplo de ventas sin adaptarlo no satisface el objetivo" |
| Conversor JSON | `JacksonJsonMessageConverter` (Spring Boot 4) | `Jackson2JsonMessageConverter` (nuestro proyecto es Spring Boot 3.2.4) | si se copia la clase de ventas no compila |
| Contraseñas de ejemplo | `clavesegura1234`, `clavederabbitmq` están en los apuntes compartidos | **No reutilizarlas**; crear claves nuevas | ya están expuestas y son débiles |
| Despliegue | los apuntes terminan con el servicio corriendo en el IDE | los JAR se despliegan en las EC2 con systemd (paso 6) | C1 exige EC2 distintas con procesos desplegados |

Lo que sí se mantiene tal cual de los apuntes: crear las EC2 con Ubuntu 24.04 y verificar que están en la misma VPC, usar RDS MySQL con usuario `admin`,
nombres de instancia RDS sin guion bajo, conectarse a la EC2 desde el navegador si SSH falla, y el flujo de clics de API Gateway y de registro de la SPA.

## Topología objetivo
| Recurso | Contenido | Puertos |
|---|---|---|
| EC2-A `mesatech-ec2-a` | ms-catalogo (publicador) + BFF | 8082 (solo EC2-A), 8080 (Gateway) |
| EC2-B `mesatech-ec2-b` | ms-solicitudes (consumidor) | 8081 (solo desde BFF/EC2-A) |
| EC2-C `mesatech-ec2-c` | RabbitMQ (Docker Compose) | 5672, 15672 |
| RDS `mesatech-rds-catalogo` | BD `mesatech_catalogo_db` | 3306 |
| RDS `mesatech-rds-solicitudes` | BD `mesatech_solicitudes_db` | 3306 |

## Paso 0. Datos previos (EP1)
1. Entra ID listo según `infrastructure/entra-id/azure-entra-id-guide.md` (API `api-cloud-native` con scope `access_as_user` y App Roles; SPA con redirect `http://localhost:3000`). 📸 EP1-01…EP1-05
2. Anotar fuera del repo: Tenant ID, Client ID de la SPA, audiencia `api://api-cloud-native`.
3. Los apuntes del 02/09 cubren **solo el registro de la SPA** (Registros de aplicaciones → Nuevo registro → Authentication → "Aplicación de página única" → URI `http://localhost:3000`).
   Para EP1 falta además el registro de la **API** (`api-cloud-native`: exponer el scope `access_as_user` y crear los App Roles Cliente, Operador y Administrador, asignarlos a los usuarios
   en Aplicaciones empresariales) y dar permiso a la SPA sobre ese scope. Sin los App Roles el token no trae `roles` y el frontend muestra "Sin rol asignado".
4. En el frontend **no se editan `authConfig.js` ni `clientId` a mano** (como en clase): los valores van en `mesatech-frontend/.env` (`REACT_APP_AZURE_CLIENT_ID`, `REACT_APP_AZURE_TENANT_ID`, `REACT_APP_API_SCOPE`).

## Paso 1. Security groups (EC2 → VPC → Security groups)
Crear 5 SG en la VPC por defecto. 📸 EP2-01 (lista de SG)
| SG | Regla de entrada | Origen |
|---|---|---|
| `mesatech-sg-ec2-a` | TCP 22 | tu IP pública /32 |
| | TCP 8080 | 0.0.0.0/0 (API Gateway no tiene IP fija; el BFF valida el JWT de nuevo) |
| `mesatech-sg-ec2-b` | TCP 22 | tu IP /32 |
| | TCP 8081 | `mesatech-sg-ec2-a` (solo el BFF) |
| `mesatech-sg-ec2-c` | TCP 22 | tu IP /32 |
| | TCP 5672 | `mesatech-sg-ec2-a` y `mesatech-sg-ec2-b` |
| | TCP 15672 | tu IP /32 |
| `mesatech-sg-rds-catalogo` | TCP 3306 | `mesatech-sg-ec2-a` |
| `mesatech-sg-rds-solicitudes` | TCP 3306 | `mesatech-sg-ec2-b` |

No abrir 8082 hacia Internet: el catálogo solo lo llama el BFF desde la misma EC2 (localhost). 📸 EP2-02…EP2-06 (reglas de cada SG)

## Paso 2. Dos RDS MySQL exclusivas (RDS → Create database)
Para cada una: Standard create, MySQL 8.0, plantilla **Free tier/Dev**, `db.t3.micro`, 20 GB, **Public access = No**, VPC por defecto, SG correspondiente,
sin Multi-AZ (con la plantilla "Capa gratuita" ya viene una sola instancia), motor MySQL 8.x (en los apuntes quedó 8.4.9; funciona con el driver del proyecto), grupo de subredes `predeterminado`, usuario maestro `admin` (contraseña guardada fuera del repo; **no puede contener `/ ' " @`**, restricción visible en la captura de creación de los apuntes del 07/10; usar letras, números y `-_`, y evitar `#` y `$` para que no afecten los archivos `.env`), *Initial database name* = `mesatech_catalogo_db` o `mesatech_solicitudes_db`.
Nombres de instancia: `mesatech-rds-catalogo` y `mesatech-rds-solicitudes`.
📸 EP2-07 (config creación catálogo), EP2-08 (solicitudes), EP2-09 (lista con ambas "Available" y endpoints distintos), EP2-10/11 (pestaña Connectivity y SG de cada una)

> **Nota (diferencia con clase):** en los apuntes la RDS quedó pública y se consultó con Workbench desde el PC. En EP2 la RDS es **privada**; para consultarla,
> conéctate por SSH a la EC2 dueña y usa `mysql` (paso 4). Si quieres un cliente gráfico, usa un túnel SSH autorizado:
> `ssh -i vockey.pem -N -L 3307:<endpoint-rds>:3306 ubuntu@<IP-EC2>` y conecta Workbench a `127.0.0.1:3307`.

## Paso 3. Tres EC2 (EC2 → Launch instance)
Ubuntu Server 24.04 LTS, key pair `vockey`, VPC por defecto, auto-assign public IP, almacenamiento **20 GB** (el predeterminado de 8 GB queda justo con Java, Maven o Docker).
En *Configuraciones de red* elegir **Seleccionar grupo de seguridad existente** y el `mesatech-sg-ec2-*` que corresponda. **No** dejar "Crear grupo de seguridad":
el asistente crea un `launch-wizard-N` con SSH abierto a `0.0.0.0/0` (se ve en las capturas del 19/10, donde además quedó HTTP 80 abierto por marcar "Permitir HTTP"). No marcar HTTP/HTTPS.
Verificar que las tres instancias estén en la **misma VPC** (pestaña Networking de cada una) 📸 EP2-12b.

**Cómo conectarte** (los apuntes del 30/09 usaron el navegador porque PuTTY no funcionó):
- *Desde tu PC (recomendado, permite `scp`):* en el Learner Lab, **AWS Details → Download PEM** (Linux/Mac) o **Download PPK** (PuTTY en Windows). El problema de PuTTY de los apuntes era que
  faltaba descargar el `.ppk`. Luego: `chmod 400 labsuser.pem` y `ssh -i labsuser.pem ubuntu@<IP-pública>`.
- *Desde el navegador (EC2 Instance Connect):* botón **Conectar → EC2 Instance Connect**. Funciona, pero entra desde rangos de AWS, **no desde tu IP**: con el SSH abierto solo a "Mi IP" fallará.
  Si lo necesitas, agrega al puerto 22 el rango de Instance Connect de us-east-1 (`18.206.107.24/29`; verificar en `ip-ranges.json`, servicio `EC2_INSTANCE_CONNECT`). Este modo no sirve para `scp`.
| Nombre | Tipo | SG |
|---|---|---|
| `mesatech-ec2-a` | t3.small | `mesatech-sg-ec2-a` |
| `mesatech-ec2-b` | t3.small | `mesatech-sg-ec2-b` |
| `mesatech-ec2-c` | t3.medium | `mesatech-sg-ec2-c` |

Asignar una **Elastic IP** a `mesatech-ec2-a`. 📸 EP2-12 (lista de instancias con Instance ID, nombre, IP privada y SG), EP2-13 (Elastic IP asociada)

## Paso 4. Java y usuarios de BD (EC2-A y EC2-B)
En cada una: `scp` de `infrastructure/ec2/setup-java.sh` y ejecutarlo → deja Java 21 y el cliente MySQL. 📸 EP2-14 (`java -version` y `uname/lsb_release`)

Crear usuarios de aplicación (desde EC2-A para catálogo y desde EC2-B para solicitudes; sin acceso desde tu PC porque la RDS es privada):
```bash
mysql -h <endpoint-rds> -u admin -p
CREATE USER 'catalogo_app'@'%' IDENTIFIED BY '<password>';
GRANT ALL PRIVILEGES ON mesatech_catalogo_db.* TO 'catalogo_app'@'%';
-- en la otra RDS: solicitudes_app sobre mesatech_solicitudes_db
FLUSH PRIVILEGES; SHOW DATABASES;
```
📸 EP2-15 (conexión desde EC2-A a RDS-Catálogo), EP2-16 (desde EC2-B a RDS-Solicitudes). Comprobar que EC2-A **no** conecta a RDS-Solicitudes (timeout) 📸 EP2-17.

## Paso 5. RabbitMQ en EC2-C (EP2 C3, C5)
```bash
# Docker Engine (repo apt oficial: https://docs.docker.com/engine/install/ubuntu/)
sudo apt update && sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER && newgrp docker
docker --version && docker compose version
```
> Los apuntes del 30/09 traen el bloque de repositorio apt de Docker con la línea `Suites:` incompleta (`{UBUNTU_CODENAME:-$VERSION_CODENAME}")` sin `$(. /etc/os-release && echo ...)`);
> si se copia tal cual, `apt update` falla. Usar el bloque de arriba, que genera la línea con el nombre real de la versión de Ubuntu.
> Docker no necesita Java en esta EC2. Con `docker compose` no hace falta `sudo` si ejecutaste `usermod -aG docker`.

📸 EP2-18 (versiones). Copiar `infrastructure/rabbitmq/` a `~/rabbitmq` en EC2-C y:
```bash
cd ~/rabbitmq
cp .env.example .env && nano .env              # contraseña admin (no mostrar)
docker compose config --quiet                  # 📸 EP2-19 (sin salida = válido)
docker compose pull                            # 📸 EP2-20
docker compose up -d                           # 📸 EP2-21
docker compose ps                              # 📸 EP2-22 (healthy)
docker compose logs --tail=40 rabbitmq         # 📸 EP2-23
ss -lnt | grep -E '5672|15672'                 # 📸 EP2-24 (puertos escuchando)
PUB_PASS='...' CONS_PASS='...' ./create-users.sh   # 📸 EP2-25 (usuarios y permisos)
```
Si el vhost, el exchange o la cola no aparecen tras `up -d`, crearlos desde la interfaz como en los apuntes del 19/10 (ver `infrastructure/rabbitmq/README.md`, plan B).
Abrir `http://<IP-pública-EC2-C>:15672` (solo tu IP) y capturar: 📸 EP2-26 vhost `mesatech`, EP2-27 exchange `catalogo.exchange`, EP2-28 cola `solicitudes.catalogo.queue` durable, EP2-29 binding `categoria.creada`, EP2-30 usuarios y permisos. Mostrar `compose.yaml` **sin** `.env`: 📸 EP2-31.
Mapeo puerto contenedor ↔ regla AWS: 📸 EP2-32 (`docker compose ps` junto a las reglas de `mesatech-sg-ec2-c`).

## Paso 6. Compilar y desplegar los servicios
En tu PC (JDK 21): `mvn -DskipTests package` en `mesatech-bff`, `mesatech-catalogo` y `mesatech-solicitudes`; subir los JAR con `scp -i labsuser.pem`.
En cada EC2 crear `/etc/mesatech/<nombre>.env` a partir del `.env.example` del servicio (IP privada de EC2-C para RabbitMQ, endpoints RDS) y ejecutar:
```bash
sudo ./install-service.sh catalogo    /opt/mesatech/mesatech-catalogo-1.0.0.jar 8082   # EC2-A
sudo ./install-service.sh bff         /opt/mesatech/mesatech-bff-1.0.0.jar 8080        # EC2-A
sudo ./install-service.sh solicitudes /opt/mesatech/mesatech-solicitudes-1.0.0.jar 8081 # EC2-B
```
En el `.env` del BFF: `SERVICES_CATALOGO_URL=http://localhost:8082`, `SERVICES_SOLICITUDES_URL=http://<IP-privada-EC2-B>:8081`.
📸 EP2-33/34/35 (`systemctl status` de cada servicio), EP2-36 (logs del consumidor conectado a RabbitMQ: `journalctl -u mesatech-solicitudes -n 30`).
Comprobar tablas: `SHOW TABLES;` en ambas RDS (`categorias`, `prioridades`… y `categoria_copia`, `solicitudes`…). 📸 EP2-37/38

## Paso 7. API Gateway (EP1)
Flujo de clics basado en los apuntes del 14/08 (adaptado a nuestras rutas y con el JWT Authorizer, que en clase no se vio):
1. API Gateway → **Crear API → API HTTP → Compilar**. Nombre `mesatech-api`. Pasos siguientes con *Siguiente* hasta **Crear**.
2. **Rutas → Crear**: `ANY /v1/{proxy+}`, `ANY /v2/{proxy+}` y, además, `OPTIONS /{proxy+}` (preflight CORS, **sin** authorizer). En clase se usó un método concreto (GET); aquí usamos `ANY` + `{proxy+}` para cubrir todas las rutas.
3. **Integraciones → Crear y asociar** a cada ruta: tipo **URI HTTP**, método `ANY`, y URL:
   - `/v1/{proxy+}` → `http://<Elastic-IP-EC2-A>:8080/v1/{proxy}`
   - `/v2/{proxy+}` → `http://<Elastic-IP-EC2-A>:8080/v2/{proxy}`
   (con `http://` explícito, sin `www.` y **conservando el prefijo** `/v1` o `/v2`; si se omite, el BFF recibe `/solicitudes` y responde 404).
4. **Autorización → Administrar autorizadores → Crear**: tipo **JWT**, fuente de identidad `$request.header.Authorization`, Issuer `https://login.microsoftonline.com/<tenant-id>/v2.0`,
   Audience `api://api-cloud-native`. Luego **Asociar** el autorizador a `/v1/{proxy+}` y `/v2/{proxy+}`.
5. **CORS → Configurar**: origen `http://localhost:3000`, métodos GET, POST, PUT, DELETE, OPTIONS, headers `authorization` **y** `content-type`, sin credenciales.
   En la captura del 14/08 se dejó origen `*` y solo el header `content-type`: sirve para una API pública sin token, pero con `Authorization: Bearer` el navegador bloquea la petición en el preflight
   si `authorization` no está permitido. Es el error más probable al conectar React.
6. **Etapas:** en clase se creó una etapa manual llamada `desarrollo` y se hizo la implementación a mano. Más simple: usar la etapa `$default` con **implementación automática**.
   Si usan una etapa con nombre (en la captura del 14/08 la URL termina en `/desarrollo`), la URL de invocación lleva `/<etapa>` y `REACT_APP_API_GATEWAY_URL` debe incluirla (`https://<id>.execute-api.us-east-1.amazonaws.com/desarrollo`).
7. Probar antes de usar React: `curl -i https://<id>.execute-api.us-east-1.amazonaws.com/v1/solicitudes` (sin token) → **401**; luego con `Authorization: Bearer <token>` → 200. En clase se probó con Postman; es equivalente.

Referencia: `infrastructure/api-gateway/`. 📸 EP1-10 (rutas), EP1-11 (integración), EP1-12 (authorizer), EP1-13 (CORS), EP1-13b (etapa e invoke URL)

## Paso 8. Frontend local contra el Gateway
`mesatech-frontend/.env` (no versionado) con `REACT_APP_API_GATEWAY_URL=https://<api-id>.execute-api.us-east-1.amazonaws.com`; `npm install && npm start`. 📸 EP1-14 (login), EP1-15 (claims con roles)

## Paso 9. Pruebas y evidencias
**EP1 (matriz de 9):** sin token → 401 (Gateway); JWT inválido/expirado → 401; JWT válido → 200; Cliente crea categoría → 403; CORS; `RESUELTA` sin `EN_PROCESO` → 422; v1 y v2; persistencia tras reiniciar. 📸 EP1-20…EP1-28
**EP2 (P1–P8):** seguir `docs/MATRIZ_PRUEBAS_EP2.md` (a crear con los datos reales) usando **una misma categoría identificable** para P2–P5.
Comandos útiles: `curl -i`, `docker compose ps`, `docker compose down` + `docker compose up -d` **sin `-v`** (P5), `sudo systemctl restart mesatech-*` (P6), `docker compose stop` (P7).
No usar "Get messages" con ack: si se inspecciona desde la UI, usar la opción que reencola (Nack requeue = true) y documentarlo.

## Antes de presentar (checklist)
- [ ] Las 3 EC2 y las 2 RDS en "running/available"; Elastic IP asociada; IPs privadas anotadas.
- [ ] Servicios `active (running)`; `categoria_copia` conectada al broker; cola con consumidor.
- [ ] Pestañas listas: RabbitMQ UI, terminal EC2-A/B/C, cliente MySQL, front en `localhost:3000`, tabla de IDs de EC2 y endpoints RDS.
- [ ] Probar el flujo completo una vez desde cero 30 min antes.
- [ ] Learner Lab: sesión iniciada hace poco (dura ~4 h). Si se reinicia, volver a ejecutar `docker compose up -d` y revisar las IPs.
