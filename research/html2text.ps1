param(
  [string]$RawDir  = 'research\raw',
  [string]$TextDir = 'research\text'
)

Add-Type -AssemblyName System.Web

function Convert-HelpHtmlToText($html) {
  $h = $html
  $h = [regex]::Replace($h, '(?s)<script.*?</script>', '')
  $h = [regex]::Replace($h, '(?s)<style.*?</style>', '')
  $h = [regex]::Replace($h, '(?s)<!--.*?-->', '')

  # Yalnizca asil icerik: class="contentpane"
  $i = $h.IndexOf('class="contentpane"')
  if ($i -ge 0) { $h = $h.Substring($i) } else {
    $j = $h.IndexOf('id="content_wrapper"')
    if ($j -ge 0) { $h = $h.Substring($j) }
  }
  # footer'a kadar kes
  $k = $h.IndexOf('All rights reserved')
  if ($k -ge 0) { $h = $h.Substring(0, $k) }

  # tablolari markdown'a cevir
  $h = [regex]::Replace($h, '(?is)</t[dh]>\s*<t[dh][^>]*>', ' | ')
  $h = [regex]::Replace($h, '(?is)</tr>', "`n")
  $h = [regex]::Replace($h, '(?is)<t[dh][^>]*>', '| ')
  $h = [regex]::Replace($h, '(?is)<br\s*/?>', "`n")
  $h = [regex]::Replace($h, '(?is)</(p|div|li|h1|h2|h3|h4|tr|table|ul|ol)>', "`n")
  $h = [regex]::Replace($h, '(?is)<li[^>]*>', '- ')
  $h = [regex]::Replace($h, '(?is)<h1[^>]*>', "`n# ")
  $h = [regex]::Replace($h, '(?is)<h2[^>]*>', "`n## ")
  $h = [regex]::Replace($h, '(?is)<h3[^>]*>', "`n### ")
  $h = [regex]::Replace($h, '(?is)<img[^>]*alt="([^"]*)"[^>]*>', '[$1]')
  $h = [regex]::Replace($h, '(?is)<span[^>]*class="[^"]*tooltip[^"]*"[^>]*>', '')
  $h = [regex]::Replace($h, '<[^>]+>', '')
  $h = [System.Web.HttpUtility]::HtmlDecode($h)
  $h = $h -replace "`r", ''
  $h = [regex]::Replace($h, '[ \t]+', ' ')
  $h = [regex]::Replace($h, '(?m)^\s*\|\s*$', '')
  $h = [regex]::Replace($h, '(\n\s*){2,}', "`n")
  return $h.Trim()
}

New-Item -ItemType Directory -Force -Path $TextDir | Out-Null
foreach ($f in Get-ChildItem ($RawDir + '\*.html')) {
  $t = Convert-HelpHtmlToText ([System.IO.File]::ReadAllText($f.FullName))
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) ($TextDir + '\' + $f.BaseName + '.txt')), $t, [System.Text.Encoding]::UTF8)
}
Write-Output ($TextDir + " -> " + (Get-ChildItem ($TextDir + '\*.txt')).Count + " dosya")
Write-Output ("ornek boyut: barracks=" + ([System.IO.File]::ReadAllText($TextDir + '\buildings_details_barracks.txt')).Length)
