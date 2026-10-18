param([string]$RawDir = 'research\raw-tr')
Add-Type -AssemblyName System.Web
$c = [System.IO.File]::ReadAllText($RawDir + '\player_points.html')
$m = [regex]::Match($c, '(?s)<table[^>]*borderlist[^>]*>(.*?)</table>')
$trs = [regex]::Matches($m.Groups[1].Value, '(?s)<tr>(.*?)</tr>')

$head = $trs[0].Groups[1].Value
$keys = @()
foreach ($x in [regex]::Matches($head, 'src="/img/buildings/([a-z]+)\.png"')) { $keys += $x.Groups[1].Value }

$levels = @()
for ($i = 1; $i -lt $trs.Count; $i++) {
  $tds = [regex]::Matches($trs[$i].Groups[1].Value, '(?s)<td[^>]*>(.*?)</td>')
  if ($tds.Count -lt 2) { continue }
  $lv = [int](($tds[0].Groups[1].Value -replace '<[^>]+>', '') -replace '[^0-9]', '')
  $obj = [ordered]@{ level = $lv }
  for ($k = 0; $k -lt $keys.Count; $k++) {
    $idx = $k + 1
    $val = 0
    if ($idx -lt $tds.Count) {
      $t = ($tds[$idx].Groups[1].Value -replace '<[^>]+>', '') -replace '[^0-9]', ''
      if ($t -ne '') { $val = [int]$t }
    }
    $obj[$keys[$k]] = $val
  }
  $levels += [pscustomobject]$obj
}

New-Item -ItemType Directory -Force -Path 'data' | Out-Null
@{ keys = $keys; levels = $levels } | ConvertTo-Json -Depth 6 | Set-Content 'data\building-points.json' -Encoding UTF8

# Markdown
$nameMap = @{ main='Kale'; stone='Taş ocağı'; wood='Oduncu Kampı'; iron='Maden ocağı'; storage='Depo'; hide='Gizli Depo';
  farm='Değirmen'; barracks='Kışla'; wall='Sur'; stable='Katır çiftliği'; market='Market';
  garage='Simyager'; snob='Köşk'; smith='Kuyumcu'; statue='Anıt' }

$md = "# Bina Puanları (seviye başına toplam puan)`n`n"
$md += "Her bina seviyesinin verdiği puan. Bir köyün puanı = binalarının puanları toplamı.`n`n"
$md += "| Sv | " + (($keys | ForEach-Object { $nameMap[$_] }) -join ' | ') + " | Satır toplamı |`n"
$md += "|" + ('---:|' * ($keys.Count + 2)) + "`n"
foreach ($row in $levels) {
  $sum = 0
  $cells = @()
  foreach ($k in $keys) { $cells += $row.$k; $sum += $row.$k }
  $md += "| $($row.level) | " + ($cells -join ' | ') + " | **$sum** |`n"
}
Set-Content 'docs\reference\puan-tablosu.md' $md -Encoding UTF8

$maxLvMap = @{ main=50; stone=50; wood=50; iron=50; storage=50; hide=30; farm=50; barracks=30; wall=20;
  stable=30; market=30; garage=5; snob=10; smith=5; statue=1 }
$total = 0
foreach ($k in $keys) {
  $row = $levels | Where-Object { $_.level -eq $maxLvMap[$k] }
  if ($row) { $total += $row.$k }
}

$md += "`n> Not: Satir toplami, TUM binalar ayni seviyede varsayilinca cikan toplamdir (sadece bilgi amacli).`n"
$md += "> **Tam gelismis bir koy = $total puan** (her binanin kendi maksimum seviyesindeki kumulatif puani toplami).`n"
Set-Content 'docs\reference\puan-tablosu.md' $md -Encoding UTF8

Write-Output ("seviye satiri: " + $levels.Count + "  tam gelismis yerlesim puanı: " + $total)
