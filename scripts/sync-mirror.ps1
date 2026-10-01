$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$tempDirectory = Join-Path $projectRoot ".tmp"
New-Item -ItemType Directory -Force -Path $tempDirectory | Out-Null
$rssFile = Join-Path $tempDirectory "rss.xml"
$backupDirectory = Join-Path $tempDirectory "backups"
New-Item -ItemType Directory -Force -Path $backupDirectory | Out-Null

Write-Host "Fetching the public source feed..."
& curl.exe -L --fail --silent --show-error --retry 3 --connect-timeout 20 --max-time 120 -o $rssFile "http://w.atwiki.jp/ava_kccthnb/rss10.xml"
if ($LASTEXITCODE -ne 0) { throw "Could not fetch the source feed" }

$pageIds = @(1, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 24, 27, 28, 29, 30, 31, 32, 33, 34)
Write-Host "Fetching the latest public backup source for every mirrored page..."
foreach ($pageId in $pageIds) {
  $backupFile = Join-Path $backupDirectory "$pageId.html"
  $backupUrl = "http://w.atwiki.jp/ava_kccthnb/rss10.xml?cmd=backup&action=source&pageid=$pageId"
  $status = & curl.exe -L --silent --show-error --retry 3 --connect-timeout 20 --max-time 120 -o $backupFile --write-out "%{http_code}" $backupUrl
  if ($LASTEXITCODE -ne 0) { throw "Could not fetch backup source for page $pageId" }
  if ($status -ne "200") { Write-Warning "Page $pageId has no publicly readable backup source (HTTP $status)." }
}

& (Join-Path $PSScriptRoot "build-pages.ps1") -RssFile $rssFile -BackupDirectory $backupDirectory
& (Join-Path $PSScriptRoot "localize-assets.ps1")
