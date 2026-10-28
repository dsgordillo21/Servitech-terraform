# Cada ejecucion crea un registro real. Compatible con Windows PowerShell 5.1 y PowerShell 7.
[CmdletBinding()]
param(
    [string]$ApiUrl,

    [ValidateRange(1, 2147483647)]
    [int]$MissingServiceId = 2147483647
)

$ErrorActionPreference = 'Stop'

function Invoke-MvpRequest {
    param(
        [string]$Method,
        [string]$Path,
        [int]$ExpectedStatus,
        [string]$Body
    )

    $request = @{
        Uri             = "$script:apiBase$Path"
        Method          = $Method
        UseBasicParsing = $true
        TimeoutSec      = 30
        ErrorAction     = 'Stop'
        Headers         = @{ Accept = 'application/json' }
    }
    if ($PSBoundParameters.ContainsKey('Body')) {
        $request.ContentType = 'application/json; charset=utf-8'
        $request.Body = $Body
    }

    $response = $null
    try {
        $response = Invoke-WebRequest @request
        $statusCode = [int]$response.StatusCode
    }
    catch {
        # PowerShell 5.1 y 7 lanzan excepciones para HTTP 400/404.
        if ($null -eq $_.Exception.Response) {
            throw "No se pudo completar $Method $Path. Revisa conexion, URL y despliegue. Si era POST, verifica si se guardo antes de repetirlo."
        }
        $statusCode = [int]$_.Exception.Response.StatusCode
    }

    if ($statusCode -ne $ExpectedStatus) {
        throw "$Method $Path devolvio HTTP $statusCode; se esperaba $ExpectedStatus. Para el caso 404, usa un -MissingServiceId confirmado como inexistente."
    }

    Write-Host "$Method $Path -> HTTP $statusCode"
    if ($ExpectedStatus -in @(200, 201)) {
        try {
            return ($response.Content | ConvertFrom-Json -ErrorAction Stop)
        }
        catch {
            throw "$Method $Path no devolvio un JSON valido."
        }
    }
}

try {
    if ([string]::IsNullOrWhiteSpace($ApiUrl)) {
        if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
            throw 'Terraform no esta disponible. Instala Terraform o proporciona -ApiUrl con la URL real de API Gateway, incluido /dev.'
        }
        $terraformDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'terraform'
        try {
            $workspace = & terraform "-chdir=$terraformDirectory" workspace show 2>$null
            if ($LASTEXITCODE -ne 0 -or "$workspace".Trim() -ne 'dev') {
                throw 'Workspace no disponible o distinto de dev.'
            }
            $ApiUrl = & terraform "-chdir=$terraformDirectory" output -raw api_url 2>$null
        }
        catch {
            throw 'No se pudo leer api_url del workspace dev. Revisa el acceso AWS y el estado compartido, o proporciona -ApiUrl con la URL real.'
        }
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ApiUrl)) {
            throw 'No se pudo obtener api_url del estado compartido. Revisa el acceso AWS y el workspace dev, o proporciona -ApiUrl. El output debe existir tras el despliegue coordinado.'
        }
    }

    $parsedUrl = $null
    if (-not [uri]::TryCreate($ApiUrl.Trim(), [UriKind]::Absolute, [ref]$parsedUrl) -or
        $parsedUrl.Scheme -ne 'https' -or -not $parsedUrl.Host -or
        $parsedUrl.UserInfo -or $parsedUrl.Query -or $parsedUrl.Fragment) {
        throw 'ApiUrl debe ser una URL HTTPS real, incluido el stage, sin credenciales, query ni fragmento.'
    }
    $script:apiBase = $parsedUrl.AbsoluteUri.TrimEnd('/')

    $expected = @{
        cliente     = 'Juan Perez'
        equipo      = 'Laptop'
        descripcion = 'No enciende'
    }

    Write-Host 'La prueba creara un servicio real en PostgreSQL.'
    $created = Invoke-MvpRequest -Method POST -Path '/servicios' -ExpectedStatus 201 -Body ($expected | ConvertTo-Json -Compress)
    $serviceId = 0
    if (-not [int]::TryParse([string]$created.id, [ref]$serviceId) -or $serviceId -le 0) {
        throw 'POST devolvio 201 pero no un ID entero positivo valido. Verifica el registro antes de repetir la prueba.'
    }
    Write-Host "ID devuelto por la API: $serviceId"

    $service = Invoke-MvpRequest -Method GET -Path "/servicios/$serviceId" -ExpectedStatus 200
    $queriedId = 0
    if (-not [int]::TryParse([string]$service.id, [ref]$queriedId) -or $queriedId -ne $serviceId) {
        throw 'El ID consultado no coincide con el ID devuelto por POST.'
    }
    foreach ($field in @('cliente', 'equipo', 'descripcion')) {
        if ($service.$field -isnot [string] -or $service.$field -cne $expected[$field]) {
            throw "El campo '$field' consultado no coincide con el enviado."
        }
    }
    Write-Output ($service | ConvertTo-Json -Depth 5)

    Invoke-MvpRequest -Method POST -Path '/servicios' -ExpectedStatus 400 -Body '{}'
    Invoke-MvpRequest -Method GET -Path "/servicios/$MissingServiceId" -ExpectedStatus 404

    Write-Host 'Prueba HTTP completada: 201, 200, 400 y 404; el ID y los datos coinciden.'
    Write-Host 'Pendiente comprobar persistencia con el responsable de PostgreSQL, CORS desde navegador y ambas invocaciones en CloudWatch.'
}
catch {
    throw "Prueba MVP fallida: $($_.Exception.Message)"
}
