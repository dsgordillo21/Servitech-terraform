# Requiere Python con venv; las dependencias se descargan para Linux, no Windows.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$buildDirectory = Join-Path $repoRoot "build"
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
$temporaryDirectory = Join-Path $buildDirectory ("tmp-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null

try {
    # Un entorno temporal proporciona pip sin modificar el Python del usuario.
    $venvDirectory = Join-Path $temporaryDirectory "venv"
    python -m venv $venvDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo crear el entorno temporal de Python."
    }
    $python = Join-Path $venvDirectory "Scripts\python.exe"
    $packageDirectory = Join-Path $temporaryDirectory "package"

    & $python -m pip install `
        --platform manylinux2014_x86_64 `
        --implementation cp `
        --python-version 3.12 `
        --abi cp312 `
        --only-binary=:all: `
        --no-compile `
        --target $packageDirectory `
        -r (Join-Path $repoRoot "lambda\requirements.txt")
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudieron instalar las dependencias Linux para Python 3.12."
    }

    foreach ($functionName in @("registrar_servicio", "consultar_servicio")) {
        $source = Join-Path $repoRoot "lambda\$functionName\lambda_function.py"
        Copy-Item -LiteralPath $source -Destination (Join-Path $packageDirectory "lambda_function.py") -Force
        $zipPath = Join-Path $buildDirectory "$functionName.zip"

        # zipfile usa rutas POSIX e incluye las librerias nativas sin carpeta padre.
        @'
from pathlib import Path
import sys
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

package = Path(sys.argv[1])
with ZipFile(sys.argv[2], "w", compression=ZIP_DEFLATED) as archive:
    for path in sorted(package.rglob("*")):
        if path.is_file():
            # Fecha y permisos fijos para obtener ZIP reproducibles.
            entry = ZipInfo(path.relative_to(package).as_posix(), (2020, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            entry.compress_type = ZIP_DEFLATED
            archive.writestr(entry, path.read_bytes())
'@ | & $python -B - $packageDirectory $zipPath
        if ($LASTEXITCODE -ne 0) {
            throw "No se pudo generar el ZIP de $functionName."
        }
        Write-Host "Paquete generado: $zipPath"
    }
}
finally {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
}
