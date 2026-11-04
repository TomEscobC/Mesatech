#!/usr/bin/env bash
# Prepara una EC2 Ubuntu 24.04 para ejecutar un microservicio Spring Boot (Java 21). Sin Docker.
set -euo pipefail
sudo apt-get update -y
sudo apt-get install -y openjdk-21-jre-headless mysql-client-core-8.0
java -version
sudo mkdir -p /opt/mesatech /etc/mesatech
sudo chown ubuntu:ubuntu /opt/mesatech
