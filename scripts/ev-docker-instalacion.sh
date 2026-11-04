#!/usr/bin/env bash
# [EP2-15] EC2-C: instalacion de Docker desde el repositorio oficial (solo lectura)
C=${C:-3.90.203.34}; K=${KEY:-$HOME/Descargas/labsuser.pem}
echo "===== [EP2-15] EC2-C: instalacion de Docker Engine y Compose desde el repositorio oficial ====="
ssh -i $K -o LogLevel=ERROR ubuntu@$C '
echo "$ cat /etc/apt/sources.list.d/docker.list"; cat /etc/apt/sources.list.d/docker.list | cut -c1-150
echo; echo "$ grep -E \"Start-Date|Commandline\" /var/log/apt/history.log   (instalacion)"
grep -E "Start-Date|Commandline" /var/log/apt/history.log | grep -B1 "docker-ce" | cut -c1-150
echo; echo "$ ls ~/rabbitmq"; ls -A ~/rabbitmq'
