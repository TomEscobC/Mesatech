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

## Si la importación de definiciones no aplica (plan B, probado en clase)
`definitions.json` se carga con `rabbitmq.conf` (`load_definitions`). No se pudo probar localmente. Si tras `docker compose up -d` no aparecen el vhost,
el exchange o la cola (`docker exec rabbitmq rabbitmqctl list_vhosts` / `list_queues -p mesatech`), crearlos desde la interfaz web como en los apuntes del 19/10
(Admin → Virtual Hosts → `mesatech`; Exchanges → `catalogo.exchange` direct durable; Queues → `solicitudes.catalogo.queue` durable;
Bindings → routing key `categoria.creada`) y luego ejecutar `create-users.sh`. La pauta admite crear los recursos por interfaz, código o archivo de definiciones.
