# ServiTech — MVP en AWS

ServiTech permite registrar y consultar servicios técnicos. Terraform administra
la infraestructura del MVP. La demostración requiere un INSERT real en PostgreSQL
y un SELECT del mismo registro por el ID devuelto; una respuesta simulada no basta.

## Arquitectura

```text
Navegador ──HTTPS──> CloudFront ──> S3 privado (HTML, CSS y JavaScript)
    │
    └──HTTPS──> API Gateway /dev
                    ├── POST /servicios ──> Lambda RegistrarServicio ──> PostgreSQL
                    └── GET /servicios/{id} ──> Lambda ConsultarServicio ──> PostgreSQL
                                                │
                                                └── CloudWatch Logs (7 días)
```

El JavaScript servido por CloudFront llama directamente a API Gateway. Las
Lambdas acceden a PostgreSQL dentro de la VPC; la base de datos no es pública.

## Estado y dependencias de integración

- Los recursos de CloudFront, S3, API Gateway, las dos Lambdas y PostgreSQL están
  definidos en el código. Esto no confirma que estén desplegados.
- La inspección inicial detectó que faltan `build/registrar_servicio.zip` y
  `build/consultar_servicio.zip`. Sin ellos, `terraform validate` falla en
  `terraform/lambdas.tf`, en las llamadas a `filebase64sha256`.
- `frontend/app.js` contiene `API_URL_PENDIENTE`. El responsable del frontend debe
  integrar la URL real del output `api_url`, incluido `/dev`, y coordinar su
  publicación. Hasta entonces no se puede completar la prueba desde navegador.
- Los grupos de logs y los outputs de esta rama deben incluirse en un despliegue
  coordinado. Si los grupos ya existen en AWS y no están en el estado compartido,
  el equipo debe coordinar su importación antes de aplicar; no borrarlos para
  resolver el conflicto.

## Requisitos y acceso

- Git.
- AWS CLI con el perfil SSO `servitech` configurado.
- Terraform compatible con la configuración del repositorio y el bloqueo S3
  `use_lockfile` del backend existente.
- Python con `venv` y acceso al índice de paquetes para ejecutar el empaquetador
  existente `scripts/build_lambdas.ps1`.
- PowerShell para los comandos de esta guía y el script de prueba.

| Configuración | Valor |
| --- | --- |
| Perfil AWS | `servitech` |
| Cuenta AWS | `694188424284` |
| Región de los recursos | `us-east-1` |
| Región de IAM Identity Center | `us-east-2` |
| Workspace compartido | `dev` |
| Rama de monitoreo | `feat/monitoring-mvp` |

Desde la raíz del repositorio, iniciar sesión y comprobar la cuenta:

```powershell
aws sso login --profile servitech
aws sts get-caller-identity --profile servitech --query Account --output text
```

La cuenta debe ser `694188424284`. IAM Identity Center utiliza `us-east-2` para
SSO; el despliegue permanece en `us-east-1`.

## Preparación y validación

El responsable de las Lambdas debe generar los paquetes reales con el script
existente, desde la raíz del repositorio:

```powershell
.\scripts\build_lambdas.ps1
```

El script empaqueta las dependencias Linux de Python 3.12 para ambas funciones.
Los ZIP de `build/` son artefactos locales ignorados por Git. No usar archivos
vacíos ni cambiar `lambdas.tf` para ocultar el error de validación.

Después, entrar en la carpeta de Terraform:

```powershell
Set-Location .\terraform
terraform init -reconfigure
terraform workspace select dev
terraform workspace show
```

Utilizar el backend S3 compartido ya definido en `backend.tf` y el workspace
existente `dev`. No crear otro backend, workspace ni estado local.

Formatear únicamente los archivos Terraform de esta responsabilidad y comprobar
el formato del conjunto sin modificar archivos de otros integrantes:

```powershell
terraform fmt monitoring.tf outputs.tf
terraform fmt -check
terraform validate
terraform plan -input=false
```

Revisar el plan completo: el estado remoto es compartido y el plan puede incluir
cambios de otros integrantes. Detenerse ante eliminaciones, reemplazos o cambios
inesperados y coordinarlos con el equipo. Los errores de dependencias ajenas deben
reportarse a su responsable, sin crear recursos sustitutos.

## Despliegue coordinado

**`terraform apply` requiere aprobación explícita y coordinación del equipo:**
afecta el estado remoto compartido. Ejecutar solamente después de resolver las
dependencias y revisar el plan en la cuenta y el workspace correctos:

```powershell
terraform apply
```

El bloqueo del backend no sustituye la coordinación entre integrantes.

## Outputs y acceso al frontend

Desde `terraform/`, después del despliegue coordinado:

```powershell
terraform output
terraform output -raw frontend_url
terraform output -raw api_url
terraform output -raw database_endpoint
terraform output -raw frontend_bucket
terraform output -raw aws_region
terraform output -raw environment
```

| Output | Contenido |
| --- | --- |
| `frontend_url` | URL HTTPS de CloudFront |
| `api_url` | URL base real de API Gateway, incluido `/dev` |
| `database_endpoint` | Host y puerto de PostgreSQL, accesibles desde la VPC |
| `frontend_bucket` | Nombre del bucket S3 privado |
| `aws_region` | Región configurada; por defecto `us-east-1` |
| `environment` | Workspace actual; debe ser `dev` |

Estos outputs no incluyen contraseñas, tokens, credenciales ni el ARN del secreto.
Los outputs se leen del estado: antes de aplicar estos cambios pueden no existir.

Para abrir el frontend:

```powershell
$frontendUrl = terraform output -raw frontend_url
if ($LASTEXITCODE -ne 0) { throw 'No se pudo obtener frontend_url.' }
Start-Process $frontendUrl
```

Usar CloudFront para acceder al sitio; el bucket S3 es privado. Si aparece el
aviso de API sin configurar, completar la dependencia de frontend indicada arriba.

## Prueba de registro y consulta

Cada ejecución del script crea un registro real de prueba. Desde la raíz:

```powershell
.\scripts\test_mvp.ps1
```

El script obtiene `api_url` del estado existente en `terraform/`. También acepta
la URL real, incluido el stage, como parámetro:

```powershell
$apiUrl = terraform -chdir=terraform output -raw api_url
if ($LASTEXITCODE -ne 0) { throw 'No se pudo obtener api_url.' }
.\scripts\test_mvp.ps1 -ApiUrl $apiUrl
```

Si Windows bloquea los archivos `.ps1`, se puede habilitar su ejecución solamente
para este proceso, sin cambiar la política persistente del equipo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test_mvp.ps1
```

Realiza `POST /servicios` con este contenido y exige HTTP 201:

```json
{
  "cliente": "Juan Perez",
  "equipo": "Laptop",
  "descripcion": "No enciende"
}
```

Lee el `id` real del JSON devuelto y llama a `GET /servicios/{id}`. Exige HTTP
200 y compara el ID y los tres campos con los datos enviados. Muestra el registro
recuperado. Un timeout de POST puede ocurrir después de guardar: comprobar lo
sucedido antes de repetir la prueba para evitar duplicados.

También comprueba estos casos:

| Caso | Solicitud | HTTP esperado |
| --- | --- | --- |
| POST válido | Los tres campos de texto no vacíos | 201 |
| POST inválido | `{}` | 400 |
| GET existente | ID devuelto por el POST | 200 |
| GET inexistente | ID positivo que no exista en la base | 404 |

Para el último caso, el script usa `2147483647` por defecto. Si ese ID existe,
elegir otro ID positivo confirmado como inexistente mediante el parámetro
`-MissingServiceId`. El script falla si recibe 200 y no declara ese caso aprobado.

La prueba HTTP verifica el comportamiento de la API. Para acreditar persistencia,
revisar junto al responsable de PostgreSQL el registro del ID creado en la tabla
`servicios`; las Lambdas integradas ejecutan INSERT/SELECT reales.

## Prueba desde navegador y CORS

Con la URL real de API integrada en el frontend y publicada:

1. Abrir `frontend_url` y las herramientas del desarrollador (Consola y Red).
2. Registrar un servicio con el formulario y guardar el ID devuelto.
3. Consultar ese ID y comprobar que los datos coincidan.
4. Verificar que el preflight `OPTIONS` y las solicitudes POST/GET funcionen
   entre el origen CloudFront y API Gateway, sin errores de CORS en la consola.

PowerShell no aplica las restricciones CORS del navegador: aprobar el script no
sustituye esta comprobación.

## CloudWatch Logs

En la consola AWS, seleccionar la cuenta del proyecto y `us-east-1`, abrir
CloudWatch → Logs → Log groups y buscar, con los nombres predeterminados actuales:

- `/aws/lambda/servitech-dev-registrar-servicio`
- `/aws/lambda/servitech-dev-consultar-servicio`

Cada grupo tiene retención de 7 días. Después de la prueba, revisar los streams y
las marcas de tiempo de ambas invocaciones. También se pueden seguir desde CLI:

```powershell
aws logs tail /aws/lambda/servitech-dev-registrar-servicio --since 10m --follow --profile servitech --region us-east-1
```

Terminar con `Ctrl+C` y repetir para la consulta:

```powershell
aws logs tail /aws/lambda/servitech-dev-consultar-servicio --since 10m --follow --profile servitech --region us-east-1
```

Las Lambdas actuales registran mensajes genéricos de error. No agregar al log
eventos completos, contraseñas, valores de secretos, tokens ni credenciales.
La retención no oculta información sensible: el código debe evitar emitirla.

## Criterios de aceptación

- [ ] Formato Terraform correcto y `terraform validate` aprobado con los ZIP reales.
- [ ] Plan completo revisado e infraestructura desplegada de forma coordinada.
- [ ] CloudFront abre el frontend con la URL de API real integrada.
- [ ] POST devuelve 201 y el ID generado por un INSERT real en PostgreSQL.
- [ ] GET de ese ID devuelve 200 y los mismos datos guardados.
- [ ] POST inválido devuelve 400 y GET inexistente devuelve 404.
- [ ] El navegador completa el flujo sin errores CORS.
- [ ] CloudWatch registra las ejecuciones de ambas Lambdas, con retención de 7 días.
- [ ] No hay credenciales expuestas en outputs, respuestas ni logs.

Un `terraform apply` exitoso por sí solo no completa el MVP.

## Retirada coordinada

**`terraform destroy` requiere aprobación explícita y coordinación de todo el
equipo:** elimina infraestructura del workspace compartido. No ejecutarlo para
limpiar solamente el trabajo individual. Antes, revisar la cuenta, el workspace,
el alcance del plan y la conservación de los datos de PostgreSQL.

Desde `terraform/`, únicamente cuando el equipo lo autorice:

```powershell
terraform workspace show
terraform plan -destroy
terraform destroy
```

La configuración actual exige una instantánea final de PostgreSQL y el bucket
del frontend contiene objetos; revisar con sus responsables cualquier impedimento
de retirada, sin cambiar infraestructura ajena ni borrar recursos manualmente.
