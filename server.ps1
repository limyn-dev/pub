
param(
  [string]$Repertoire = (Join-Path $PSScriptRoot "html"),
  [int]   $Port     = 8080
)

$Repertoire = (Resolve-Path $Repertoire).Path

$listener = [System.Net.HttpListener]::new()
# "+" = écoute sur toutes les interfaces (accessible depuis le réseau local)
$listener.Prefixes.Add("http://+:$Port/")
try {
  $listener.Start()
}
catch {
  Write-Host "Impossible de démarrer le serveur : $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Exécutez une fois en PowerShell administrateur :" -ForegroundColor Yellow
  Write-Host "  netsh http add urlacl url=http://+:$Port/ user=$env:USERNAME" -ForegroundColor Yellow
  Write-Host "  New-NetFirewallRule -DisplayName 'HTTP $Port' -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow" -ForegroundColor Yellow
  exit 1
}

$ipLocales = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
  Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
  ForEach-Object { $_.IPAddressToString }

Write-Host "====================================="
Write-Host " Serveur HTTP démarré"
Write-Host " Répertoire : $Repertoire"
Write-Host " URL locale : http://localhost:$Port"
foreach ($ip in $ipLocales) {
  Write-Host " URL réseau : http://${ip}:$Port"
}
Write-Host " Arrêt    : CTRL+C"
Write-Host "====================================="

$mimeTypes = @{
  ".html" = "text/html; charset=utf-8"
  ".htm"  = "text/html; charset=utf-8"
  ".css"  = "text/css"
  ".js"   = "application/javascript"
  ".json" = "application/json"
  ".png"  = "image/png"
  ".jpg"  = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".gif"  = "image/gif"
  ".svg"  = "image/svg+xml"
  ".ico"  = "image/x-icon"
  ".txt"  = "text/plain"
  ".pdf"  = "application/pdf"
  ".woff" = "font/woff"
  ".woff2"= "font/woff2"
}

$running = $true

try {
  while ($running -and $listener.IsListening) {
    $context = $listener.GetContext()

    try {
      # Arrêt du serveur demandé par le bouton de index.html (appel local uniquement)
      if ($context.Request.Url.AbsolutePath -eq "/shutdown") {
        if ($context.Request.HttpMethod -eq "POST" -and $context.Request.IsLocal) {
          $bytes = [System.Text.Encoding]::UTF8.GetBytes("Serveur arrêté")
          $context.Response.StatusCode = 200
          $context.Response.ContentType = "text/plain; charset=utf-8"
          $context.Response.ContentLength64 = $bytes.Length
          $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
          $running = $false
          Write-Host "Arrêt demandé depuis la page"
        }
        else {
          $context.Response.StatusCode = 405
        }
        continue
      }

      $urlPath = [System.Uri]::UnescapeDataString(
        $context.Request.Url.AbsolutePath.TrimStart("/")
      )

      if ([string]::IsNullOrWhiteSpace($urlPath)) {
        $urlPath = "index.html"
      }

      $filePath = [System.IO.Path]::GetFullPath(
        (Join-Path $Repertoire $urlPath)
      )

      # Empêche de sortir du répertoire publié
      if (-not $filePath.StartsWith(
        $Repertoire.TrimEnd('\') + '\',
        [StringComparison]::OrdinalIgnoreCase
      ) -and $filePath -ne (Join-Path $Repertoire "index.html")) {
        throw "Accès interdit"
      }

      if (Test-Path $filePath -PathType Container) {
        $filePath = Join-Path $filePath "index.html"
      }

      if (Test-Path $filePath -PathType Leaf) {
        $extension = [System.IO.Path]::GetExtension($filePath).ToLower()
        $mime = $mimeTypes[$extension]

        if (-not $mime) {
          $mime = "application/octet-stream"
        }

        $bytes = [System.IO.File]::ReadAllBytes($filePath)

        $context.Response.StatusCode = 200
        $context.Response.ContentType = $mime
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)

        Write-Host "200 OK : $urlPath"
      }
      else {
        $context.Response.StatusCode = 404
        Write-Host "404 NOT FOUND : $urlPath"
      }
    }
    catch {
      $context.Response.StatusCode = 403
      Write-Host "403 FORBIDDEN : $($_.Exception.Message)"
    }
    finally {
      $context.Response.Close()
    }
  }
}
finally {
  $listener.Stop()
  $listener.Close()
}
