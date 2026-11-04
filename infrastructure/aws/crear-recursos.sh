#!/usr/bin/env bash
# Crea la infraestructura AWS de MesaTech (EP1/EP2) en el Learner Lab.
# Ejecutar UNA sola vez, desde AWS CloudShell (ícono >_ de la consola, región us-east-1).
#   5 security groups, 2 RDS MySQL privadas, 3 EC2 Ubuntu 24.04 y 1 Elastic IP para EC2-A.
# La contraseña maestra de las RDS se pide por teclado (oculta) y no se guarda en ningún archivo.
set -euo pipefail
export AWS_DEFAULT_REGION=us-east-1
KEY=vockey

echo "== Datos necesarios =="
read -rp "Tu IP pública (míralo en https://checkip.amazonaws.com, NO es la de CloudShell): " MYIP
[[ "$MYIP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "IP inválida"; exit 1; }
MYIP="$MYIP/32"
read -rsp "Contraseña maestra de las RDS (8+ caracteres, sin / ' \" @): " DBPASS; echo
[[ ${#DBPASS} -ge 8 && "$DBPASS" != *[/\'\"@]* ]] || { echo "Contraseña inválida para RDS"; exit 1; }

cat <<MSG

Se crearán (consumen crédito del Learner Lab mientras estén encendidos):
  - 5 security groups (mesatech-sg-ec2-a, -b, -c, mesatech-sg-rds-catalogo, mesatech-sg-rds-solicitudes)
  - 2 RDS MySQL db.t3.micro, privadas (mesatech-rds-catalogo, mesatech-rds-solicitudes)
  - 3 EC2 Ubuntu 24.04: mesatech-ec2-a (t3.small), mesatech-ec2-b (t3.small), mesatech-ec2-c (t3.medium), 20 GB
  - 1 Elastic IP asociada a mesatech-ec2-a
MSG
read -rp "Escribe SI para continuar: " OK; [ "$OK" = "SI" ] || { echo "Cancelado"; exit 0; }

VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
echo "VPC por defecto: $VPC"

mk_sg() { aws ec2 create-security-group --group-name "$1" --description "$2" --vpc-id "$VPC" --query GroupId --output text; }
allow_cidr() { aws ec2 authorize-security-group-ingress --group-id "$1" --protocol tcp --port "$2" --cidr "$3" >/dev/null; }
allow_sg()   { aws ec2 authorize-security-group-ingress --group-id "$1" --protocol tcp --port "$2" --source-group "$3" >/dev/null; }

echo "== Security groups =="
SG_A=$(mk_sg mesatech-sg-ec2-a "EC2-A catalogo y BFF")
SG_B=$(mk_sg mesatech-sg-ec2-b "EC2-B solicitudes")
SG_C=$(mk_sg mesatech-sg-ec2-c "EC2-C RabbitMQ")
SG_RC=$(mk_sg mesatech-sg-rds-catalogo "RDS catalogo")
SG_RS=$(mk_sg mesatech-sg-rds-solicitudes "RDS solicitudes")
allow_cidr "$SG_A" 22 "$MYIP";  allow_cidr "$SG_A" 8080 0.0.0.0/0     # 8080: API Gateway no tiene IP fija; el BFF valida el JWT
allow_cidr "$SG_B" 22 "$MYIP";  allow_sg "$SG_B" 8081 "$SG_A"          # solo el BFF llama a solicitudes
allow_cidr "$SG_C" 22 "$MYIP";  allow_cidr "$SG_C" 15672 "$MYIP"
allow_sg "$SG_C" 5672 "$SG_A";  allow_sg "$SG_C" 5672 "$SG_B"          # AMQP solo desde A y B
allow_sg "$SG_RC" 3306 "$SG_A"; allow_sg "$SG_RS" 3306 "$SG_B"         # cada RDS solo desde su EC2

echo "== RDS (tardan varios minutos en quedar disponibles) =="
mk_rds() { aws rds create-db-instance --db-instance-identifier "$1" --engine mysql --db-instance-class db.t3.micro \
  --allocated-storage 20 --storage-type gp2 --master-username admin --master-user-password "$DBPASS" \
  --db-name "$2" --vpc-security-group-ids "$3" --no-publicly-accessible --no-multi-az \
  --backup-retention-period 0 >/dev/null; }
mk_rds mesatech-rds-catalogo mesatech_catalogo_db "$SG_RC"
mk_rds mesatech-rds-solicitudes mesatech_solicitudes_db "$SG_RS"

echo "== EC2 =="
AMI=$(aws ec2 describe-images --owners 099720109477 \
  --filters 'Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*' 'Name=state,Values=available' \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
echo "AMI Ubuntu 24.04: $AMI"
mk_ec2() { aws ec2 run-instances --image-id "$AMI" --instance-type "$2" --key-name "$KEY" --security-group-ids "$3" \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=20,VolumeType=gp3}' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$1}]" --query 'Instances[0].InstanceId' --output text; }
EC2_A=$(mk_ec2 mesatech-ec2-a t3.small "$SG_A")
EC2_B=$(mk_ec2 mesatech-ec2-b t3.small "$SG_B")
EC2_C=$(mk_ec2 mesatech-ec2-c t3.medium "$SG_C")
aws ec2 wait instance-running --instance-ids "$EC2_A" "$EC2_B" "$EC2_C"
ALLOC=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)
aws ec2 associate-address --instance-id "$EC2_A" --allocation-id "$ALLOC" >/dev/null

echo "== Esperando a las RDS (puede tardar 5-15 min) =="
aws rds wait db-instance-available --db-instance-identifier mesatech-rds-catalogo mesatech-rds-solicitudes

echo
echo "================ RESUMEN (sin contraseñas): copiar y pegar en el chat ================"
aws ec2 describe-instances --instance-ids "$EC2_A" "$EC2_B" "$EC2_C" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,InstanceId,PrivateIpAddress,PublicIpAddress]' --output table
aws rds describe-db-instances --query 'DBInstances[?starts_with(DBInstanceIdentifier,`mesatech-`)].[DBInstanceIdentifier,Endpoint.Address,PubliclyAccessible]' --output table
echo "SG: A=$SG_A B=$SG_B C=$SG_C RDS-cat=$SG_RC RDS-sol=$SG_RS  VPC=$VPC  ElasticIP-alloc=$ALLOC"
