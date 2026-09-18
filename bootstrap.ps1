# ============================================================
#  DEVFACTORY - bootstrap completo (Windows)
#  Instala o que faltar, cria o ambiente e executa o assistente.
#  Uso:  powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1
#  (ou apenas de duplo clique em start_windows.bat)
#  Compativel com Windows PowerShell 5.1 (padrao do Windows 10/11).
# ============================================================

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Write-Step($msg)  { Write-Host "`n[DEVFACTORY] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "[DEVFACTORY] $msg"   -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "[DEVFACTORY] $msg"   -ForegroundColor Yellow }

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path','User')
}

function Test-PythonWorks($exe) {
    # Retorna true somente se o executavel responde "--version" com "Python 3".
    # Evita o falso "python" da Microsoft Store (stub que so abre a loja).
    try {
        $out = & $exe --version 2>&1
        return ($LASTEXITCODE -eq 0 -and ("$out" -match "Python 3"))
    } catch { return $false }
}

function Test-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn2 "winget nao encontrado."
        Write-Host  "  Instale 'App Installer' pela Microsoft Store (gratuito) e rode novamente."
        Write-Host  "  Link direto: ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
        return $false
    }
    return $true
}

# ── 1. Garantir Python 3.12 ──────────────────────────────────────────────
Write-Step "Verificando Python..."

$pyExe = $null
if     (Get-Command py -ErrorAction SilentlyContinue)     { if (Test-PythonWorks "py")     { $pyExe = "py" } }
if (-not $pyExe -and (Get-Command python -ErrorAction SilentlyContinue)) { if (Test-PythonWorks "python") { $pyExe = "python" } }

if (-not $pyExe) {
    Write-Warn2 "Python 3 nao encontrado - instalando via winget (aguarde, pode demorar)..."
    if (-not (Test-Winget)) { exit 1 }
    winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
    Refresh-Path
    if     (Get-Command py -ErrorAction SilentlyContinue)     { if (Test-PythonWorks "py")     { $pyExe = "py" } }
    if (-not $pyExe -and (Get-Command python -ErrorAction SilentlyContinue)) { if (Test-PythonWorks "python") { $pyExe = "python" } }
    if (-not $pyExe) {
        Write-Warn2 "O Python foi instalado mas ainda nao esta no PATH desta sessao."
        Write-Host  "  Feche e reabra o terminal (ou rode o start_windows.bat de novo)."
        exit 1
    }
}
$ver = & $pyExe --version 2>&1
Write-Ok "Python OK: $ver"

# ── 2. Ambiente virtual (.venv) ──────────────────────────────────────────
# Espaco em disco no drive onde o projeto esta (as dependencias ocupam ~4 GB)
$drive = (Resolve-Path $PSScriptRoot).Drive.Name
$freeGB = [math]::Round((Get-PSDrive $drive).Free / 1GB, 1)
if ($freeGB -lt 4.5) {
    Write-Warn2 "ATENCAO: so ha $freeGB GB livres no drive ${drive}:. As dependencias precisam de ~4 GB."
    Write-Host   "  Libere espaco (Lixeira, Downloads, Limpeza de Disco) antes de continuar."
}

# Limpa temporarios travados de instalacoes anteriores (causa de WinError 32)
Remove-Item "$env:TEMP\pip-*" -Recurse -Force -ErrorAction SilentlyContinue

$venvPython = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Step "Criando ambiente virtual (.venv)..."
    & $pyExe -m venv .venv
    if (-not (Test-Path $venvPython)) { Write-Warn2 "Falha ao criar o .venv."; exit 1 }
}
Write-Ok "Ambiente virtual pronto."

# ── 3. Dependencias (primeira vez, ou quando requirements.txt mudar) ────
$marker = Join-Path $PSScriptRoot ".venv\.deps_installed"
$reqHash = (Get-FileHash (Join-Path $PSScriptRoot "requirements.txt") -Algorithm MD5).Hash
$needDeps = $true
if ((Test-Path $marker) -and ((Get-Content $marker -Raw -ErrorAction SilentlyContinue) -match $reqHash)) { $needDeps = $false }
if ($needDeps) {
    # Pre-download retomavel dos 3 maiores pacotes (~176 MB) via curl nativo do
    # Windows: se a conexao cair, retoma do ponto exato (o pip nao sabe retomar).
    $wheelsDir = Join-Path $PSScriptRoot "wheels"
    $bigWheels = @(
        @{ file = "pyqt6_qt6-6.11.2-py3-none-win_amd64.whl";
           url  = "https://files.pythonhosted.org/packages/f6/56/62457dd9b5738f65b9fb4ac6b3120bc0bfa0bc335857fdd456b94b0a6079/pyqt6_qt6-6.11.2-py3-none-win_amd64.whl" },
        @{ file = "opencv_python-5.0.0.93-cp37-abi3-win_amd64.whl";
           url  = "https://files.pythonhosted.org/packages/21/f0/9fa6e85cb10c8eb36a0222d27e50fe381b86ce49a55446bf39f491727564/opencv_python-5.0.0.93-cp37-abi3-win_amd64.whl" },
        @{ file = "opencv_contrib_python-5.0.0.93-cp37-abi3-win_amd64.whl";
           url  = "https://files.pythonhosted.org/packages/09/29/6985260569ee3c7f6fcae252bc06e2a843e5b90eed665a2936bdd26fa283/opencv_contrib_python-5.0.0.93-cp37-abi3-win_amd64.whl" }
    )
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        New-Item $wheelsDir -ItemType Directory -Force | Out-Null
        foreach ($w in $bigWheels) {
            $dest = Join-Path $wheelsDir $w.file
            if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 10MB)) { Write-Ok "Pacote grande ja baixado: $($w.file)"; continue }
            Write-Step "Pre-baixando $($w.file) (retomavel, aguarde)..."
            & curl.exe -L -C - --retry 20 --retry-all-errors --retry-delay 3 --connect-timeout 30 -o $dest $w.url
            if ($LASTEXITCODE -ne 0) { Write-Warn2 "Pre-download falhou ($($w.file)) - o pip tentara baixar normalmente. Rodar de novo retoma de onde parou." }
        }
    }

    # Instala primeiro os wheels grandes do disco local: quando a versao do
    # PyPI empata com a local, o pip prefere o indice e re-baixa 176 MB a toa.
    # Com --no-index ele consome o arquivo baixado e pula o download.
    if (Test-Path $wheelsDir) {
        Get-ChildItem $wheelsDir -Filter *.whl -ErrorAction SilentlyContinue | ForEach-Object {
            & $venvPython -m pip install --no-index --no-deps $_.FullName --quiet 2>$null
            if ($LASTEXITCODE -eq 0) { Write-Ok "Instalado do disco local: $($_.Name)" }
        }
    }

    Write-Step "Instalando dependencias (5-10 min na primeira execucao)..."
    & $venvPython -m pip install --upgrade pip --quiet
    $pipArgs = @("-m", "pip", "install", "-r", "requirements.txt", "--retries", "15", "--timeout", "90")
    if (Test-Path $wheelsDir) { $pipArgs += @("--find-links", $wheelsDir) }
    & $venvPython @pipArgs
    if ($LASTEXITCODE -ne 0) { Write-Warn2 "Falha ao instalar dependencias. RODE ESTE SCRIPT DE NOVO - os pacotes grandes ja baixados serao reaproveitados."; exit 1 }

    Write-Step "Baixando navegadores do motor de automacao (Playwright)..."
    & $venvPython -m playwright install chromium firefox

    Set-Content -Path $marker -Value $reqHash -Encoding ASCII
    Write-Ok "Dependencias instaladas."
} else {
    Write-Ok "Dependencias ja instaladas (pulado)."
}

# ── 4. Executar o assistente ─────────────────────────────────────────────
Write-Step "Iniciando o assistente (Mark LIV)..."
& $venvPython main.py
if ($LASTEXITCODE -ne 0) {
    Write-Warn2 "O assistente encerrou com erro. Leia a mensagem acima."
    if ($Host.Name -eq "ConsoleHost") { pause }
}
