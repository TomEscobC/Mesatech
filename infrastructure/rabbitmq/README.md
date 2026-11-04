# RabbitMQ MesaTech (EC2-C)

Recursos que declara `definitions.json`: virtual host `mesatech`, exchange direct durable `catalogo.exchange`,
cola durable `solicitudes.catalogo.queue`, binding con routing key `categoria.creada`.
Los **usuarios y sus contraseñas no van en el repositorio**: se crean con `create-users.sh` tras levantar el broker.

| Usuario | Configure | Write | Read | Uso |
|---|---|---|---|---|
| mesatech_publicador | `^$` | `^catalogo\.exchange$` | `^$` | ms-catalogo publica |
| mesatech_consumidor | `^$` | `^$` | `^solicitudes\.catalogo\.queue$` | ms-solicitudes consume |

Sin tags de administración. `guest` no se usa de forma remota.

## Orden
```bash
cp .env.example .env && nano .env      # contraseña admin
docker compose config --quiet
docker compose pull
docker compose up -d
docker compose ps
docker compose logs --tail=50 rabbitmq
PUB_PASS=... CONS_PASS=... ./create-users.sh
```
