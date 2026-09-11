<#
.SYNOPSIS
    Starts a Cloudflare Tunnel for the EcoScrap Backend (127.0.0.1:8000).
.DESCRIPTION
    Creates a secure, public HTTPS tunnel using Cloudflare Tunnel (`cloudflared`).
    Supports Quick Tunnels (*.trycloudflare.com) and Static Named Tunnels.
    Outputs the public endpoint and writes it to `tunnel_url.txt`.
#>

param (
    [int]$Port = 8000,
    [string]$TunnelName = "attenda",
    [string]$StaticDomain = "ecoscrap.srishakthicgpa.in",
    [switch]$QuickTunnel = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "       EcoScrap Cloudflare Tunnel Launcher             " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Locate cloudflared executable
$cloudflaredCmd = Get-Command cloudflared -ErrorAction SilentlyContinue

if (-not $cloudflaredCmd) {
    # Check default install locations
    $defaultPaths = @(
        "C:\Program Files (x86)\cloudflared\cloudflared.exe",
        "C:\Program Files\cloudflared\cloudflared.exe",
        "$env:LOCALAPPDATA\Programs\cloudflared\cloudflared.exe",
        "$env:USERPROFILE\AppData\Roaming\npm\cloudflared.cmd"
    )
    foreach ($p in $defaultPaths) {
        if (Test-Path $p) {
            $cloudflaredCmd = $p
            break
        }
    }
}

if (-not $cloudflaredCmd) {
    Write-Host "[!] cloudflared executable not found." -ForegroundColor Yellow
    Write-Host "    Downloading latest cloudflared-windows-amd64.exe..." -ForegroundColor Cyan
    $toolDir = Join-Path $PSScriptRoot "tools"
    if (-not (Test-Path $toolDir)) { New-Item -ItemType Directory -Path $toolDir -Force | Out-Null }
    $exePath = Join-Path $toolDir "cloudflared.exe"
    Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile $exePath
    $cloudflaredCmd = $exePath
    Write-Host "[+] Downloaded to $exePath" -ForegroundColor Green
} else {
    $cloudflaredPath = if ($cloudflaredCmd -is [string]) { $cloudflaredCmd } else { $cloudflaredCmd.Source }
    Write-Host "[+] Using cloudflared: $cloudflaredPath" -ForegroundColor Green
}

$localTarget = "http://127.0.0.1:$Port"
Write-Host "[+] Target backend service: $localTarget" -ForegroundColor Cyan

$tunnelUrlFile = Join-Path $PSScriptRoot "tunnel_url.txt"
$configJsonFile = Join-Path $PSScriptRoot "frontend\assets\config.json"

# If a static named tunnel is requested (default)
if (-not $QuickTunnel -and $TunnelName -ne "") {
    $staticUrl = "https://$StaticDomain"
    $staticApi = "$staticUrl/api"
    Set-Content -Path $tunnelUrlFile -Value $staticUrl
    
    # Ensure config.json points to the static endpoint
    $configContent = @{
        api_url = $staticApi
        fallback_url = "http://127.0.0.1:8000/api"
        tunnel_domain = $StaticDomain
        environment = "production"
    } | ConvertTo-Json -Depth 2
    Set-Content -Path $configJsonFile -Value $configContent

    Write-Host "`n========================================================" -ForegroundColor Green
    Write-Host "  CLOUDFLARE STATIC DOMAIN ACTIVE!                      " -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host "  Static Domain:    $staticUrl" -ForegroundColor Cyan
    Write-Host "  API Endpoint:     $staticApi" -ForegroundColor Yellow
    Write-Host "  Tunnel Name:      $TunnelName" -ForegroundColor White
    Write-Host "  Local Backend:    $localTarget" -ForegroundColor Gray
    Write-Host "  Config Bundled:   $configJsonFile" -ForegroundColor DarkCyan
    Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  The Flutter mobile app connects to this static domain " -ForegroundColor White
    Write-Host "  automatically on ANY network (cellular 4G/5G, Wi-Fi). " -ForegroundColor White
    Write-Host "========================================================`n" -ForegroundColor Green

    & cloudflared tunnel run $TunnelName
    exit
}

# Zero-config Quick Tunnel mode
Write-Host "[+] Starting Cloudflare Quick Tunnel for $localTarget..." -ForegroundColor Yellow
Write-Host "    Establishing secure edge connections..." -ForegroundColor Gray

$tunnelUrlFile = Join-Path $PSScriptRoot "tunnel_url.txt"
if (Test-Path $tunnelUrlFile) { Remove-Item $tunnelUrlFile -Force }

# Launch cloudflared process and monitor output for trycloudflare.com URL
$psi = New-Object System.Diagnostics.ProcessStartInfo
if ($cloudflaredCmd -is [string]) {
    $psi.FileName = $cloudflaredCmd
} else {
    $psi.FileName = $cloudflaredCmd.Source
}
$psi.Arguments = "tunnel --url $localTarget"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $false

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi

$tunnelFound = $false

$outputHandler = {
    param($sender, $e)
    if ($e.Data) {
        Write-Host $e.Data -ForegroundColor Gray
        if ($e.Data -match "https://[a-zA-Z0-9-]+\.trycloudflare\.com") {
            $url = $matches[0]
            $apiUrl = "$url/api"
            Set-Content -Path $tunnelUrlFile -Value $url
            $quickConfig = @{
                api_url = $apiUrl
                fallback_url = "http://127.0.0.1:8000/api"
                tunnel_domain = ($url -replace "https://", "")
                environment = "development"
            } | ConvertTo-Json -Depth 2
            Set-Content -Path $configJsonFile -Value $quickConfig
            Write-Host "`n========================================================" -ForegroundColor Green
            Write-Host "  CLOUDFLARE PUBLIC TUNNEL ACTIVE!                      " -ForegroundColor White -BackgroundColor DarkGreen
            Write-Host "========================================================" -ForegroundColor Green
            Write-Host "  Public Base URL: $url" -ForegroundColor Cyan
            Write-Host "  API Base URL:    $apiUrl" -ForegroundColor Yellow
            Write-Host "  Saved URL to:    $tunnelUrlFile" -ForegroundColor Green
            Write-Host "  Config Bundled:  $configJsonFile" -ForegroundColor DarkCyan
            Write-Host "--------------------------------------------------------" -ForegroundColor DarkGray
            Write-Host "  To run Flutter using this tunnel:" -ForegroundColor White
            Write-Host "    flutter run --dart-define=API_URL=$apiUrl" -ForegroundColor White
            Write-Host "  Or configure directly inside the app using the" -ForegroundColor White
            Write-Host "  'Server Config' (gear/cloud icon) dialog." -ForegroundColor White
            Write-Host "========================================================`n" -ForegroundColor Green
        }
    }
}

$proc.add_OutputDataReceived($outputHandler)
$proc.add_ErrorDataReceived($outputHandler)

$proc.Start() | Out-Null
$proc.BeginOutputReadLine()
$proc.BeginErrorReadLine()

Write-Host "[+] Tunnel process started (PID: $($proc.Id)). Press Ctrl+C to stop.`n" -ForegroundColor Cyan

try {
    $proc.WaitForExit()
} finally {
    if (-not $proc.HasExited) {
        $proc.Kill()
    }
}
