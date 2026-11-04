#!/usr/bin/env bash
# Crea el HTTP API de MesaTech con JWT Authorizer (Microsoft Entra ID) y CORS. Ejecutar UNA vez desde AWS CloudShell (us-east-1).
# Los IDs de Entra no son secretos. Ajustar si cambian.
set -euo pipefail
export AWS_DEFAULT_REGION=us-east-1
TENANT=051da654-8e26-4bd0-86fb-394e76049f92
API_APP=a1dae715-5db4-4aff-86c2-4a53d0cd850a
BFF_HOST=3.234.33.87          # Elastic IP de mesatech-ec2-a (BFF en :8080)
ORIGIN=http://localhost:3000

# Evita duplicados si una ejecución anterior falló a medias
EXIST=$(aws apigatewayv2 get-apis --query "Items[?Name=='mesatech-api'].ApiId" --output text)
if [ -n "$EXIST" ]; then echo "Ya existe una API mesatech-api ($EXIST). Elimínala con: aws apigatewayv2 delete-api --api-id $EXIST"; exit 1; fi

API_ID=$(aws apigatewayv2 create-api --name mesatech-api --protocol-type HTTP \
  --cors-configuration "{\"AllowOrigins\":[\"$ORIGIN\"],\"AllowMethods\":[\"GET\",\"POST\",\"PUT\",\"DELETE\",\"OPTIONS\"],\"AllowHeaders\":[\"authorization\",\"content-type\"],\"MaxAge\":300}" \
  --query ApiId --output text)

AUTH_ID=$(aws apigatewayv2 create-authorizer --api-id "$API_ID" --authorizer-type JWT --name entra-jwt \
  --identity-source '$request.header.Authorization' \
  --jwt-configuration "{\"Audience\":[\"api://$API_APP\",\"$API_APP\"],\"Issuer\":\"https://login.microsoftonline.com/$TENANT/v2.0\"}" \
  --query AuthorizerId --output text)

for V in v1 v2; do
  INT=$(aws apigatewayv2 create-integration --api-id "$API_ID" --integration-type HTTP_PROXY --integration-method ANY \
    --integration-uri "http://$BFF_HOST:8080/$V/{proxy}" --payload-format-version 1.0 --query IntegrationId --output text)
  aws apigatewayv2 create-route --api-id "$API_ID" --route-key "ANY /$V/{proxy+}" --target "integrations/$INT" \
    --authorization-type JWT --authorizer-id "$AUTH_ID" >/dev/null
  # Preflight CORS: el navegador envía OPTIONS sin token; si pasara por el authorizer respondería 401 y React quedaría bloqueado
  aws apigatewayv2 create-route --api-id "$API_ID" --route-key "OPTIONS /$V/{proxy+}" --target "integrations/$INT" \
    --authorization-type NONE >/dev/null
done

aws apigatewayv2 create-stage --api-id "$API_ID" --stage-name '$default' --auto-deploy >/dev/null
URL="https://$API_ID.execute-api.us-east-1.amazonaws.com"
echo "API_ID=$API_ID  AUTHORIZER=$AUTH_ID"
echo "URL de invocación: $URL"
echo "--- sin token (esperado 401):"; curl -s -o /dev/null -w "HTTP %{http_code}\n" "$URL/v1/solicitudes"
