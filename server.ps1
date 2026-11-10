
param(
  [string]$Repertoire = ".\html",
  [int]   $Port     = 8080
)

$Repertoire = (Resolve-Path $Repertoire).Path

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "====================================="
Write-Host " Serveur HTTP démarré"
Write-Host " Répertoire : $Repertoire"
Write-Host " URL    : http://localhost:$Port"
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

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()

    try {
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
