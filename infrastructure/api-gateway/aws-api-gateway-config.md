# Configuración de AWS API Gateway (HTTP API) para MesaTech Cloud

AWS API Gateway es el **único punto de entrada** público para el frontend React. Garantiza la seguridad en el borde mediante un JWT Authorizer conectado a Microsoft Entra ID y redirige el tráfico hacia el Backend for Frontend (BFF) alojado en Amazon EC2.

---

## 1. Creación de la HTTP API

1. En la consola de AWS, ir a **API Gateway**.
2. Seleccionar **Create API** y elegir **HTTP API** > **Build**.
3. **API Name:** `mesatech-api-gateway`
4. Dejar el Stage por defecto como `$default` con auto-deploy activado.

---

## 2. Configuración del JWT Authorizer

1. En el menú lateral de la API, ir a **Authorization** > pestaña **Manage authorizers** > **Create**.
2. **Authorizer type:** `JWT`
3. **Name:** `EntraIdJwtAuthorizer`
4. **Identity source:** `$request.header.Authorization`
5. **Issuer URL:** `https://login.microsoftonline.com/<TENANT_ID>/v2.0`
6. **Audience:** `api://<Client-ID-de-la-API>` y tambien `<Client-ID-de-la-API>` (`api://api-cloud-native` fue rechazado por el portal)
7. Presionar **Create**.

---

## 3. Configuración de Rutas e Integración HTTP hacia EC2

1. Ir a **Integrations** > **Manage integrations** > **Create**.
   - **Integration type:** `HTTP URI`
   - **HTTP method:** `ANY`
   - **URL:** `http://<EC2_PUBLIC_IP_OR_DNS>:8080/{proxy}`
2. Ir a **Routes** y crear las siguientes rutas vinculándolas con la integración y el autorizador JWT:
   - `ANY /v1/{proxy+}` -> Autorizador: `EntraIdJwtAuthorizer` -> Integración: `EC2-BFF`
   - `ANY /v2/{proxy+}` -> Autorizador: `EntraIdJwtAuthorizer` -> Integración: `EC2-BFF`

*Nota: La ruta `/v1/{proxy+}` captura solicitudes como `/v1/solicitudes`, `/v1/solicitudes/{id}/estado`, `/v1/catalogo/categorias`, etc.*

---

## 4. Configuración de CORS

1. En el menú lateral, seleccionar **CORS**.
2. Hacer clic en **Configure** y definir:
   - **Access-Control-Allow-Origin:**
     - `http://localhost:3000` (entorno de desarrollo React)
     - `https://<tu-dominio-spa>.s3-website.amazonaws.com` (o CloudFront en producción)
   - **Access-Control-Allow-Headers:**
     - `authorization`
     - `content-type`
     - `accept`
     - `origin`
     - `x-requested-with`
   - **Access-Control-Allow-Methods:**
     - `GET`
     - `POST`
     - `PUT`
     - `DELETE`
     - `OPTIONS`
   - **Max age:** `300` segundos (5 minutos)
3. Guardar los cambios. API Gateway responderá de forma automática y nativa a las peticiones `OPTIONS` (Preflight) del navegador sin necesidad de reenviarlas a EC2.

---

## 5. Script de Aprovisionamiento Automatizado (AWS CLI)

Si dispones de AWS CLI configurado, puedes ejecutar los siguientes comandos:

```bash
# 1. Crear HTTP API
API_ID=$(aws apigatewayv2 create-api \
  --name "mesatech-api-gateway" \
  --protocol-type HTTP \
  --cors-configuration "AllowOrigins=[\"http://localhost:3000\"],AllowMethods=[\"GET\",\"POST\",\"PUT\",\"DELETE\",\"OPTIONS\"],AllowHeaders=[\"authorization\",\"content-type\",\"accept\"]" \
  --query "ApiId" --output text)

# 2. Crear JWT Authorizer
AUTH_ID=$(aws apigatewayv2 create-authorizer \
  --api-id $API_ID \
  --authorizer-type JWT \
  --identity-source '$request.header.Authorization' \
  --name "EntraIdJwtAuthorizer" \
  --jwt-configuration "Issuer=https://login.microsoftonline.com/<TENANT_ID>/v2.0,Audience=[\"api://api-cloud-native\"]" \
  --query "AuthorizerId" --output text)

# 3. Crear Integración hacia el BFF en EC2
INT_ID=$(aws apigatewayv2 create-integration \
  --api-id $API_ID \
  --integration-type HTTP_PROXY \
  --integration-method ANY \
  --integration-uri "http://<EC2_IP>:8080/{proxy}" \
  --payload-format-version "1.0" \
  --query "IntegrationId" --output text)

# 4. Crear Rutas protegidas
aws apigatewayv2 create-route \
  --api-id $API_ID \
  --route-key "ANY /v1/{proxy+}" \
  --authorization-type JWT \
  --authorizer-id $AUTH_ID \
  --target "integrations/$INT_ID"

aws apigatewayv2 create-route \
  --api-id $API_ID \
  --route-key "ANY /v2/{proxy+}" \
  --authorization-type JWT \
  --authorizer-id $AUTH_ID \
  --target "integrations/$INT_ID"

# 5. Crear Stage por defecto
aws apigatewayv2 create-stage \
  --api-id $API_ID \
  --stage-name '$default' \
  --auto-deploy
```
