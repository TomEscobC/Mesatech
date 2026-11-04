# Guía paso a paso AWS: EP1 rehecho y EP2 (MesaTech Cloud)

Convención de capturas: guardar en `evidencias/` como `EP1-xx.png` / `EP2-xx.png` (📸 = captura). Una captura por paso, sin contraseñas ni
secretos en pantalla, con pie de figura "Figura N: qué prueba / qué requisito cubre".
Entorno: AWS Academy Learner Lab (región **us-east-1**, VPC por defecto, key pair `vockey`). Las IPs públicas cambian al detener el laboratorio;
entre servicios se usan **IPs privadas** y para el BFF una **Elastic IP**.

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

## Paso 1. Security groups (EC2 → VPC → Security groups)
Crear 5 SG en la VPC por defecto. 📸 EP2-01 (lista de SG)
| SG | Regla de entrada | Origen |
|---|---|---|
| `sg-ec2-a` | TCP 22 | tu IP pública /32 |
| | TCP 8080 | 0.0.0.0/0 (API Gateway no tiene IP fija; el BFF valida el JWT de nuevo) |
| `sg-ec2-b` | TCP 22 | tu IP /32 |
| | TCP 8081 | `sg-ec2-a` (solo el BFF) |
| `sg-ec2-c` | TCP 22 | tu IP /32 |
| | TCP 5672 | `sg-ec2-a` y `sg-ec2-b` |
| | TCP 15672 | tu IP /32 |
| `sg-rds-catalogo` | TCP 3306 | `sg-ec2-a` |
| `sg-rds-solicitudes` | TCP 3306 | `sg-ec2-b` |

No abrir 8082 hacia Internet: el catálogo solo lo llama el BFF desde la misma EC2 (localhost). 📸 EP2-02…EP2-06 (reglas de cada SG)

## Paso 2. Dos RDS MySQL exclusivas (RDS → Create database)
Para cada una: Standard create, MySQL 8.0, plantilla **Free tier/Dev**, `db.t3.micro`, 20 GB, **Public access = No**, VPC por defecto, SG correspondiente,
sin Multi-AZ, usuario maestro `admin` (contraseña guardada fuera del repo), *Initial database name* = `mesatech_catalogo_db` o `mesatech_solicitudes_db`.
Nombres de instancia: `mesatech-rds-catalogo` y `mesatech-rds-solicitudes`.
📸 EP2-07 (config creación catálogo), EP2-08 (solicitudes), EP2-09 (lista con ambas "Available" y endpoints distintos), EP2-10/11 (pestaña Connectivity y SG de cada una)

## Paso 3. Tres EC2 (EC2 → Launch instance)
Ubuntu Server 24.04 LTS, key pair `vockey`, VPC por defecto, auto-assign public IP.
| Nombre | Tipo | SG |
|---|---|---|
| `mesatech-ec2-a` | t3.small | `sg-ec2-a` |
| `mesatech-ec2-b` | t3.small | `sg-ec2-b` |
| `mesatech-ec2-c` | t3.medium | `sg-ec2-c` |

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
Abrir `http://<IP-pública-EC2-C>:15672` (solo tu IP) y capturar: 📸 EP2-26 vhost `mesatech`, EP2-27 exchange `catalogo.exchange`, EP2-28 cola `solicitudes.catalogo.queue` durable, EP2-29 binding `categoria.creada`, EP2-30 usuarios y permisos. Mostrar `compose.yaml` **sin** `.env`: 📸 EP2-31.
Mapeo puerto contenedor ↔ regla AWS: 📸 EP2-32 (`docker compose ps` junto a las reglas de `sg-ec2-c`).

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
HTTP API `mesatech-api`: integración HTTP a `http://<Elastic-IP-EC2-A>:8080`. Rutas `ANY /v1/{proxy+}` y `ANY /v2/{proxy+}` con URI de integración
`http://<IP>:8080/v1/{proxy}` y `/v2/{proxy}` (conserva el prefijo), más `OPTIONS` sin authorizer. JWT Authorizer: issuer
`https://login.microsoftonline.com/<tenant>/v2.0`, audience `api://api-cloud-native`. CORS: origen `http://localhost:3000`, métodos GET/POST/PUT/DELETE/OPTIONS,
headers `Authorization, Content-Type`. Referencia: `infrastructure/api-gateway/`. 📸 EP1-10 (rutas), EP1-11 (integración), EP1-12 (authorizer), EP1-13 (CORS)

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
