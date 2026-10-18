param(
  [string]$ListFile = 'research\urls.txt',
  [int]$From = 1,
  [int]$To = 9999,
  [string]$OutDir = 'research\raw-tr',
  [int]$DelaySec = 4,
  [string]$BaseUrl = 'https://s59-tr.kingsage.gameforge.com/help.php'
)

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$lines = Get-Content $ListFile | Where-Object { $_ -match '\S' -and -not $_.TrimStart().StartsWith('#') }

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
try {
  Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -WebSession $session -TimeoutSec 40 -Headers @{ 'User-Agent' = 'Mozilla/5.0' } | Out-Null
} catch {}

$i = 0; $okCount = 0; $failCount = 0
foreach ($line in $lines) {
  $i++
  if ($i -lt $From -or $i -gt $To) { continue }

  $parts = $line -split '\|'
  $name = $parts[0].Trim()
  $q = $parts[1].Trim()
  $url = $BaseUrl + '?' + $q
  $ok = $false

  for ($t = 1; $t -le 6; $t++) {
    try {
      $r = Invoke-WebRequest -Uri $url -UseBasicParsing -WebSession $session -TimeoutSec 40 `
        -Headers @{ 'User-Agent' = 'Mozilla/5.0'; 'Referer' = $BaseUrl }
      if ($r.StatusCode -eq 200 -and $r.Content.Length -gt 5000) {
        [System.IO.File]::WriteAllText((Join-Path (Get-Location) ($OutDir + '\' + $name + '.html')), $r.Content, [System.Text.Encoding]::UTF8)
        $ok = $true; break
      }
    } catch {}
    Start-Sleep -Seconds $DelaySec
  }

  if ($ok) { Write-Output ("OK   {0,-26} {1}" -f $name, $url); $okCount++ }
  else { Write-Output ("FAIL {0,-26} {1}" -f $name, $url); $failCount++ }
  Start-Sleep -Seconds $DelaySec
}
Write-Output ("=== TR batch [{0}..{1}] ok={2} fail={3} ===" -f $From, $To, $okCount, $failCount)
