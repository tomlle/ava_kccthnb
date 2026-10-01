$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$assetsRoot = Join-Path $projectRoot "assets\uploads"
New-Item -ItemType Directory -Force -Path $assetsRoot | Out-Null

$htmlFiles = @(
  Get-ChildItem -LiteralPath (Join-Path $projectRoot "pages") -Filter "*.html" -File
  Get-Item -LiteralPath (Join-Path $projectRoot "index.html")
)

$documents = @{}
$remoteSources = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($file in $htmlFiles) {
  $html = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
  $documents[$file.FullName] = $html
  foreach ($match in [regex]::Matches($html, '(?i)<img\b[^>]*?\bsrc=["''](?<url>https?://[^"'']+)["'']')) {
    [void]$remoteSources.Add([Net.WebUtility]::HtmlDecode($match.Groups['url'].Value))
  }
}

$manifest = [ordered]@{}
$expectedFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$assetNumber = 0
foreach ($source in ($remoteSources | Sort-Object)) {
  $assetNumber += 1
  $pageIdMatch = [regex]::Match($source, '(?i)[?&]pageid=(\d+)')
  $pageId = if ($pageIdMatch.Success) { $pageIdMatch.Groups[1].Value } else { "unknown" }
  $fileMatch = [regex]::Match($source, '(?i)[?&]file=([^&]+)')
  $originalName = if ($fileMatch.Success) { [Uri]::UnescapeDataString($fileMatch.Groups[1].Value) } else { "asset" }
  $extension = [IO.Path]::GetExtension($originalName).ToLowerInvariant()
  if ($extension -notmatch '^\.(?:jpe?g|png|gif|webp|bmp|svg)$') { $extension = ".bin" }

  $pageDirectory = Join-Path $assetsRoot "page-$pageId"
  New-Item -ItemType Directory -Force -Path $pageDirectory | Out-Null
  $localName = "{0:D3}{1}" -f $assetNumber, $extension
  $destination = Join-Path $pageDirectory $localName
  [void]$expectedFiles.Add([IO.Path]::GetFullPath($destination))

  if ($source -match '(?i)atwiki(?:img)?\.(?:com|jp)|w\.atwiki\.jp') {
    $queryIndex = $source.IndexOf('?')
    if ($queryIndex -lt 0) { throw "Cannot localize AtWiki asset without query: $source" }
    $downloadUrl = "http://w.atwiki.jp/ava_kccthnb/rss10.xml?" + $source.Substring($queryIndex + 1)
  } else {
    $downloadUrl = $source
  }

  Write-Host "Downloading asset $assetNumber/$($remoteSources.Count): $originalName"
  & curl.exe -L --fail --silent --show-error --retry 3 --connect-timeout 20 --max-time 180 -o $destination $downloadUrl
  if ($LASTEXITCODE -ne 0) { throw "Could not download asset: $source" }
  if ((Get-Item -LiteralPath $destination).Length -eq 0) { throw "Downloaded an empty asset: $source" }

  $webPath = "assets/uploads/page-$pageId/$localName"
  $manifest[$source] = $webPath
}

foreach ($file in $htmlFiles) {
  $html = $documents[$file.FullName]
  foreach ($entry in $manifest.GetEnumerator()) {
    $html = $html.Replace($entry.Key, $entry.Value)
    $html = $html.Replace([Net.WebUtility]::HtmlEncode($entry.Key), $entry.Value)
  }
  [IO.File]::WriteAllText($file.FullName, $html, [Text.UTF8Encoding]::new($false))
}

$manifestPath = Join-Path $assetsRoot "manifest.json"
$manifestJson = ($manifest | ConvertTo-Json -Depth 3).Replace("`r`n", "`n").Replace("`r", "`n")
[IO.File]::WriteAllText($manifestPath, $manifestJson, [Text.UTF8Encoding]::new($false))
[void]$expectedFiles.Add([IO.Path]::GetFullPath($manifestPath))
foreach ($file in Get-ChildItem -LiteralPath $assetsRoot -Recurse -File) {
  if (-not $expectedFiles.Contains($file.FullName)) { Remove-Item -LiteralPath $file.FullName -Force }
}
Write-Host "Localized $($manifest.Count) external image assets."
