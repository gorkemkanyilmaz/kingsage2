param(
  [string]$RawDir  = 'research\raw',
  [string]$DataDir = 'data',
  [string]$DocDir  = 'docs\reference'
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path ($DocDir + '\buildings') | Out-Null
New-Item -ItemType Directory -Force -Path ($DocDir + '\units') | Out-Null

function StripTags([string]$s) {
  if ($null -eq $s) { return '' }
  $s = [regex]::Replace($s, '(?is)<br\s*/?>', ' ')
  $s = [regex]::Replace($s, '<[^>]+>', '')
  $s = [System.Net.WebUtility]::HtmlDecode($s)
  $s = [regex]::Replace($s, '\s+', ' ')
  return $s.Trim()
}

function ToNum([string]$s) {
  if ($null -eq $s) { return 0 }
  $t = ($s -replace '[^0-9]', '')
  if ($t -eq '') { return 0 }
  return [int64]$t
}

function ResName([string]$src) {
  switch -Regex ($src) {
    'res1\.png' { return 'wood' }
    'res2\.png' { return 'stone' }
    'res3\.png' { return 'iron' }
    'worker\.png' { return 'settlers' }
    default { return 'unknown' }
  }
}

function Parse-Requirements([string]$html) {
  $m = [regex]::Match($html, '(?s)(?:Requirements|Gereksinimler)</th>\s*</tr>\s*<tr>\s*<td>(.*?)</td>')
  if (-not $m.Success) { return @() }
  $cell = $m.Groups[1].Value
  $out = @()
  foreach ($mm in [regex]::Matches($cell, '(?s)<a[^>]*>(.*?)</a>\s*\((?:Level|Seviye)\s*(\d+)\)')) {
    $out += [pscustomobject]@{
      name  = (StripTags $mm.Groups[1].Value)
      level = [int]$mm.Groups[2].Value
    }
  }
  return $out
}

function Parse-Description([string]$html) {
  $m = [regex]::Match($html, '(?s)<h1[^>]*>.*?</h1>\s*<p>(.*?)</p>')
  if (-not $m.Success) { return '' }
  return (StripTags $m.Groups[1].Value)
}

# ---------------- BUILDINGS ----------------
$buildings = @()
foreach ($f in (Get-ChildItem ($RawDir + '\buildings_details_*.html') | Sort-Object Name)) {
  $key  = $f.BaseName.Replace('buildings_details_', '')
  if ($key -eq 'city') { continue }   # genel 'Buildings' sayfasi
  $html = [System.IO.File]::ReadAllText($f.FullName)

  $name = StripTags ([regex]::Match($html, '(?s)<h1[^>]*>(.*?)</h1>').Groups[1].Value)
  $maxM = [regex]::Match($html, '(?:Maximum level|Maksimum seviye):\s*<b>(\d+)</b>')
  $maxLevel = if ($maxM.Success) { [int]$maxM.Groups[1].Value } else { 0 }

  $tblM = [regex]::Match($html, '(?s)<table class="borderlist small">(.*?)</table>')
  $rows = @()
  $lastColLabel = ''
  if ($tblM.Success) {
    $tbl = $tblM.Groups[1].Value
    $head = [regex]::Match($tbl, '(?s)<tr>(.*?)</tr>').Groups[1].Value
    $ths = [regex]::Matches($head, '(?s)<th[^>]*>(.*?)</th>') | ForEach-Object { StripTags $_.Groups[1].Value }
    if ($ths.Count -ge 4) { $lastColLabel = $ths[$ths.Count - 1] }

    $trs = [regex]::Matches($tbl, '(?s)<tr>(.*?)</tr>')
    for ($i = 1; $i -lt $trs.Count; $i++) {
      $tds = [regex]::Matches($trs[$i].Groups[1].Value, '(?s)<td[^>]*>(.*?)</td>')
      if ($tds.Count -lt 5) { continue }
      $level = ToNum (StripTags $tds[0].Groups[1].Value)
      $res = @{ wood = 0; stone = 0; iron = 0 }
      for ($c = 1; $c -le 3; $c++) {
        $cellHtml = $tds[$c].Groups[1].Value
        $srcM = [regex]::Match($cellHtml, 'src="([^"]+)"')
        $nm = if ($srcM.Success) { ResName $srcM.Groups[1].Value } else { 'unknown' }
        if ($res.ContainsKey($nm)) { $res[$nm] = ToNum (StripTags $cellHtml) }
      }
      $wk = StripTags $tds[4].Groups[1].Value
      $wkNums = [regex]::Matches($wk, '\d+') | ForEach-Object { [int]$_.Value }
      $lastVal = if ($ths.Count -ge 4) { StripTags $tds[$tds.Count - 1].Groups[1].Value } else { '' }
      $rows += [pscustomobject]@{
        level        = $level
        wood         = $res.wood
        stone        = $res.stone
        iron         = $res.iron
        workersLevel = if ($wkNums.Count -ge 1) { $wkNums[0] } else { 0 }
        workersTotal = if ($wkNums.Count -ge 2) { $wkNums[1] } else { 0 }
        lastColumn   = $lastVal
      }
    }
  }

  $buildings += [pscustomobject]@{
    key          = $key
    name         = $name
    maxLevel     = $maxLevel
    lastColumn   = $lastColLabel
    description  = Parse-Description $html
    requirements = @(Parse-Requirements $html)
    levels       = $rows
  }
}

# ---------------- UNITS (detay) ----------------
$units = @()
foreach ($f in (Get-ChildItem ($RawDir + '\units_details_*.html') | Sort-Object Name)) {
  $key  = $f.BaseName.Replace('units_details_', '')
  $html = [System.IO.File]::ReadAllText($f.FullName)

  $name = StripTags ([regex]::Match($html, '(?s)<h1[^>]*>(.*?)</h1>').Groups[1].Value)
  $descM = [regex]::Match($html, '(?s)<h1[^>]*>(.*?)</h1>\s*<p>(.*?)</p>')
  $desc = if ($descM.Success) { StripTags $descM.Groups[2].Value } else { '' }

  $costs = @{ wood = 0; stone = 0; iron = 0 }
  $costM = [regex]::Match($html, '(?s)<th>(?:Costs|Giderler)</th>.*?<td[^>]*>(.*?)</td>\s*<td[^>]*>(.*?)</td>\s*<td[^>]*>(.*?)</td>\s*<td[^>]*>(.*?)</td>')
  $settlers = 0; $speed = ''; $carry = 0
  if ($costM.Success) {
    $costCell = $costM.Groups[1].Value
    foreach ($mm in [regex]::Matches($costCell, 'src="([^"]+)"\s*/?>?\s*([0-9\.]+)')) {
      $nm = ResName $mm.Groups[1].Value
      if ($costs.ContainsKey($nm)) { $costs[$nm] = ToNum $mm.Groups[2].Value }
    }
    $settlers = ToNum (StripTags $costM.Groups[2].Value)
    $speed = StripTags $costM.Groups[3].Value
    $carry = ToNum (StripTags $costM.Groups[4].Value)
  }

  $stats = @{}
  foreach ($mm in [regex]::Matches($html, '(?s)<th>[^<]*</th>\s*<td>(.*?)</td>')) {
    $cell = $mm.Groups[1].Value
    $srcM = [regex]::Match($cell, 'src="([^"]+)"')
    if (-not $srcM.Success) { continue }
    $src = $srcM.Groups[1].Value
    $val = ToNum (StripTags $cell)
    if     ($src -match 'units/att\.png')        { $stats['attack'] = $val }
    elseif ($src -match 'units/def_cav\.png')    { $stats['defenceCav'] = $val }
    elseif ($src -match 'units/def_archer\.png') { $stats['defenceArch'] = $val }
    elseif ($src -match 'units/def\.png')        { $stats['defenceInf'] = $val }
  }

  $units += [pscustomobject]@{
    key            = $key
    name           = $name
    description    = $desc
    costWood       = $costs.wood
    costStone      = $costs.stone
    costIron       = $costs.iron
    settlers       = $settlers
    speed          = $speed
    carryBooty     = $carry
    attack         = $stats['attack']
    defenceInf     = $stats['defenceInf']
    defenceCav     = $stats['defenceCav']
    defenceArch    = $stats['defenceArch']
    requirements   = @(Parse-Requirements $html)
  }
}

# ---------------- UNITS (genel tablolar) ----------------
$ovHtml = [System.IO.File]::ReadAllText($RawDir + '\units.html')
$tables = [regex]::Matches($ovHtml, '(?s)<table[^>]*class="[^"]*borderlist[^"]*"[^>]*>.*?</table>')

function UnitKeyFromHref([string]$h) { if ($h -match 'unit=([a-z]+)') { return $Matches[1] } return '' }

$research = @(); $train = @(); $combat = @()
foreach ($t in $tables) {
  $txt = $t.Value
  if ($txt -match 'def_cav\.png') {
    foreach ($mm in [regex]::Matches($txt, '(?s)<tr>(.*?)</tr>')) {
      $tds = [regex]::Matches($mm.Groups[1].Value, '(?s)<td[^>]*>(.*?)</td>')
      if ($tds.Count -lt 7) { continue }
      $combat += [pscustomobject]@{
        key = UnitKeyFromHref ([regex]::Match($tds[0].Groups[1].Value, 'href="([^"]+)"').Groups[1].Value)
        name = StripTags $tds[0].Groups[1].Value
        attack = ToNum (StripTags $tds[1].Groups[1].Value)
        defenceInf = ToNum (StripTags $tds[2].Groups[1].Value)
        defenceCav = ToNum (StripTags $tds[3].Groups[1].Value)
        defenceArch = ToNum (StripTags $tds[4].Groups[1].Value)
        mobility = ToNum (StripTags $tds[5].Groups[1].Value)
        loadCapacity = ToNum (StripTags $tds[6].Groups[1].Value)
      }
    }
  }
  elseif ($txt -match 'worker\.png') {
    foreach ($mm in [regex]::Matches($txt, '(?s)<tr>(.*?)</tr>')) {
      $tds = [regex]::Matches($mm.Groups[1].Value, '(?s)<td[^>]*>(.*?)</td>')
      if ($tds.Count -lt 6) { continue }
      $train += [pscustomobject]@{
        key = UnitKeyFromHref ([regex]::Match($tds[0].Groups[1].Value, 'href="([^"]+)"').Groups[1].Value)
        name = StripTags $tds[0].Groups[1].Value
        stone = ToNum (StripTags $tds[1].Groups[1].Value)
        wood  = ToNum (StripTags $tds[2].Groups[1].Value)
        iron  = ToNum (StripTags $tds[3].Groups[1].Value)
        settlers = ToNum (StripTags $tds[4].Groups[1].Value)
        time = StripTags $tds[5].Groups[1].Value
      }
    }
  }
  elseif ($txt -match 'clock-icon') {
    foreach ($mm in [regex]::Matches($txt, '(?s)<tr>(.*?)</tr>')) {
      $tds = [regex]::Matches($mm.Groups[1].Value, '(?s)<td[^>]*>(.*?)</td>')
      if ($tds.Count -lt 5) { continue }
      $research += [pscustomobject]@{
        key = UnitKeyFromHref ([regex]::Match($tds[0].Groups[1].Value, 'href="([^"]+)"').Groups[1].Value)
        name = StripTags $tds[0].Groups[1].Value
        stone = ToNum (StripTags $tds[1].Groups[1].Value)
        wood  = ToNum (StripTags $tds[2].Groups[1].Value)
        iron  = ToNum (StripTags $tds[3].Groups[1].Value)
        time = StripTags $tds[4].Groups[1].Value
      }
    }
  }
}

# ---------------- JSON cikti ----------------
$buildings | ConvertTo-Json -Depth 8 | Set-Content -Path ($DataDir + '\buildings.json') -Encoding UTF8
@{ units = $units; research = $research; training = $train; combat = $combat } |
  ConvertTo-Json -Depth 8 | Set-Content -Path ($DataDir + '\units.json') -Encoding UTF8

# ---------------- Markdown referanslar ----------------
$bIdx = @("# Binalar - Referans`n")
foreach ($b in $buildings) {
  $md = "# $($b.name)  ``($($b.key))``  `n`n"
  $md += "$($b.description)`n`n"
  $md += "**Maksimum seviye:** $($b.maxLevel)  `n"
  if ($b.requirements.Count -gt 0) {
    $req = ($b.requirements | ForEach-Object { "$($_.name) (Sv $($_.level))" }) -join ', '
    $md += "**Gereksinimler:** $req  `n"
  } else { $md += "**Gereksinimler:** yok  `n" }
  $md += "`n## Seviye tablosu`n`n"
  if ($b.lastColumn) {
    $lbl = $b.lastColumn
    $md += "| Sv | Odun | Taş | Demir | Vatandaş (bu sv / toplam) | $lbl |`n"
    $md += "|---:|---:|---:|---:|---:|---|`n"
    foreach ($r in $b.levels) {
      $md += "| $($r.level) | $($r.wood) | $($r.stone) | $($r.iron) | $($r.workersLevel) / $($r.workersTotal) | $($r.lastColumn) |`n"
    }
  } else {
    $md += "| Sv | Odun | Taş | Demir | Vatandaş (bu sv / toplam) |`n"
    $md += "|---:|---:|---:|---:|---:|`n"
    foreach ($r in $b.levels) {
      $md += "| $($r.level) | $($r.wood) | $($r.stone) | $($r.iron) | $($r.workersLevel) / $($r.workersTotal) |`n"
    }
  }
  $md | Set-Content -Path ($DocDir + '\buildings\' + $b.key + '.md') -Encoding UTF8
  $bIdx += "- [$($b.name) - ``$($b.key)``](buildings/$($b.key).md) — maks. seviye $($b.maxLevel), $($b.levels.Count) seviye"
}

$uIdx = @("# Askerler - Referans`n")
foreach ($u in ($units | Sort-Object name)) {
  $md = "# $($u.name)  ``($($u.key))``  `n`n"
  $md += "$($u.description)`n`n"
  $md += "| Özellik | Değer |`n|---|---|`n"
  $md += "| Eğitim maliyeti (Odun) | $($u.costWood) |`n"
  $md += "| Eğitim maliyeti (Taş) | $($u.costStone) |`n"
  $md += "| Eğitim maliyeti (Demir) | $($u.costIron) |`n"
  $md += "| Vatandaş | $($u.settlers) |`n"
  $md += "| Hız | $($u.speed) |`n"
  $md += "| Taşıma kapasitesi | $($u.carryBooty) |`n"
  $md += "| Saldırı değeri | $($u.attack) |`n"
  $md += "| Savunma — Piyade | $($u.defenceInf) |`n"
  $md += "| Savunma — Süvari | $($u.defenceCav) |`n"
  $md += "| Savunma — Okçu | $($u.defenceArch) |`n"
  if ($u.requirements.Count -gt 0) {
    $req = ($u.requirements | ForEach-Object { "$($_.name) (Sv $($_.level))" }) -join ', '
    $md += "| Gereksinimler | $req |`n"
  }
  $md | Set-Content -Path ($DocDir + '\units\' + $u.key + '.md') -Encoding UTF8
  $uIdx += "- [$($u.name) - ``$($u.key)``](units/$($u.key).md) — saldırı $($u.attack) / savunma $($u.defenceInf)/$($u.defenceCav)/$($u.defenceArch)"
}

$bIdx | Set-Content -Path ($DocDir + '\buildings\README.md') -Encoding UTF8
$uIdx | Set-Content -Path ($DocDir + '\units\README.md') -Encoding UTF8

Write-Output ("buildings: " + $buildings.Count + "  units: " + $units.Count + "  research: " + $research.Count + "  training: " + $train.Count + "  combat: " + $combat.Count)
