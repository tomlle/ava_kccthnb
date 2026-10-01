param(
  [Parameter(Mandatory = $true)][string]$RssFile,
  [string]$BackupDirectory
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$pagesDirectory = Join-Path $projectRoot "pages"
New-Item -ItemType Directory -Force -Path $pagesDirectory | Out-Null

$pageTitles = [ordered]@{
  1 = "トップページ"
  6 = "クランメンバー"
  17 = "例のアイツによるクランメンバー紹介"
  7 = "マウスクリック速度"
  9 = "おもしろ画像倉庫"
  10 = "武器カスタム"
  11 = "だんごむし的SR有利ポジ"
  12 = "BLACK SCENT_dango-mushi"
  13 = "PM開幕ランニングコース"
  14 = "DUAL SIGHT ルート１"
  15 = "HAMMER BLOW ルート１"
  19 = "MG4KEステルスマーケティング"
  18 = "FOX_HUNTING_おまけ"
  20 = "AIRPLANE@MG"
  21 = "MG4KEになるために"
  23 = "FOX_HUNTING@MG"
  24 = "FOX HUNTING ルート１"
  27 = "INDIA@MG"
  28 = "ケツドラマーへの道"
  29 = "ケツドラマーの極意"
  30 = "FOX HUNTING ルート２"
  31 = "BLACK_SCENT@MG"
  32 = "MG4KEとMG4KE_T-REXの相違点と考察"
  33 = "BLACK SCENT ルート１"
  16 = "KCCT本部語録"
  8 = "テストページ"
  34 = "デイリーまとめ"
  2 = "メニュー"
  3 = "右メニュー"
}

function Convert-WikiInline([string]$text) {
  $result = [Net.WebUtility]::HtmlEncode($text)
  $result = [regex]::Replace($result, '\[\[(.*?)&gt;(https?://.*?)\]\]', '<a href="$2">$1</a>')

  for ($pass = 0; $pass -lt 10; $pass += 1) {
    $before = $result
    $result = [regex]::Replace($result, '&amp;color\(([^)]*)\)\{([^{}]*)\}', {
      param($match)
      $colors = $match.Groups[1].Value.Split(',', 2)
      $foreground = $colors[0].Trim()
      $background = if ($colors.Count -gt 1) { $colors[1].Trim() } else { '' }
      $styles = [Collections.Generic.List[string]]::new()
      if ($foreground -match '^(?:#[0-9a-fA-F]{3,8}|[a-zA-Z]+|rgb\([0-9, ]+\))$') { $styles.Add("color:$foreground") }
      if ($background -match '^(?:#[0-9a-fA-F]{3,8}|[a-zA-Z]+|rgb\([0-9, ]+\))$') { $styles.Add("background-color:$background") }
      if ($styles.Count -eq 0) { return $match.Groups[2].Value }
      return "<span class=`"wiki-color`" style=`"$($styles -join ';')`">$($match.Groups[2].Value)</span>"
    })
    $result = [regex]::Replace($result, '&amp;size\((\d+)\)\{([^{}]*)\}', '<span class="wiki-size" style="font-size:$1px">$2</span>')
    $result = [regex]::Replace($result, '&amp;font\((\d+)(?:px)?\)\{([^{}]*)\}', '<span class="wiki-size" style="font-size:$1px">$2</span>')
    $result = [regex]::Replace($result, '&amp;bold\(\)\{([^{}]*)\}', '<strong>$1</strong>')
    if ($result -eq $before) { break }
  }
  return $result
}

function Convert-WikiText([string]$source, [int]$pageId = 0) {
  $builder = [Text.StringBuilder]::new()
  $headings = [Collections.Generic.List[object]]::new()
  $tocMarker = '<!--WIKI_TOC-->'
  foreach ($line in ($source -split "`r?`n")) {
    if ($line -match '^#ref\(([^,\)]+)(.*)\)$') {
      $imageName = $Matches[1].Trim()
      $options = $Matches[2]
      $encodedName = [Uri]::EscapeDataString($imageName)
      $sizeAttributes = ""
      if ($options -match '(?:^|,)width=(\d+)') { $sizeAttributes += " width=`"$($Matches[1])`"" }
      if ($options -match '(?:^|,)height=(\d+)') { $sizeAttributes += " height=`"$($Matches[1])`"" }
      $imageUrl = "http://cdn50.atwikiimg.com/ava_kccthnb?cmd=upload&amp;act=open&amp;pageid=$pageId&amp;file=$encodedName"
      [void]$builder.AppendLine("<p><img src=`"$imageUrl`" alt=`"$([Net.WebUtility]::HtmlEncode($imageName))`"$sizeAttributes></p>")
      continue
    }
    $encoded = Convert-WikiInline $line
    if ($line -match '^(\*{1,3})(.+)$') {
      $level = $Matches[1].Length + 1
      $headingText = $Matches[2]
      $headingId = "wiki-heading-$($headings.Count + 1)"
      $headings.Add([pscustomobject]@{ Level = $level; Id = $headingId; Text = $headingText })
      $headingHtml = Convert-WikiInline $headingText
      [void]$builder.AppendLine("<h$level id=`"$headingId`">$headingHtml</h$level>")
      continue
    }
    if ($line -eq '----') { [void]$builder.AppendLine('<hr>'); continue }
    if ($line -match '^#contents') { [void]$builder.AppendLine($tocMarker); continue }
    if ([string]::IsNullOrWhiteSpace($line)) { [void]$builder.AppendLine('<div class="spacer"></div>'); continue }
    [void]$builder.AppendLine("<p>$encoded</p>")
  }
  $html = $builder.ToString()
  if ($html.Contains($tocMarker)) {
    $tocItems = foreach ($heading in $headings) {
      $safeHeading = [Net.WebUtility]::HtmlEncode($heading.Text)
      "<li class=`"wiki-toc-level-$($heading.Level)`"><a href=`"#$($heading.Id)`">$safeHeading</a></li>"
    }
    $toc = "<nav class=`"wiki-toc`" aria-label=`"目次`"><ul>`n$($tocItems -join "`n")`n</ul></nav>"
    $html = $html.Replace($tocMarker, $toc)
  }
  return $html
}

function Get-MenuHtml {
  if ($script:leftMenuHtml) { return $script:leftMenuHtml }
  $items = foreach ($entry in $pageTitles.GetEnumerator()) {
    if ($entry.Key -in @(2, 3)) { continue }
    "<li><a href=`"pages/$($entry.Key).html`">$([Net.WebUtility]::HtmlEncode($entry.Value))</a></li>"
  }
  return @"
<h3>メニュー</h3>
<ul>
$($items -join "`n")
<li><a href="pages/2.html">メニュー</a></li>
<li><a href="pages/3.html">右メニュー</a></li>
</ul>
<hr>
<h3>リンク</h3>
<ul>
  <li><a href="https://atwiki.jp/">@wiki</a></li>
  <li><a href="https://atwiki.jp/guide/">@wikiご利用ガイド</a></li>
</ul>
"@
}

function Get-PageHtml([int]$id, [string]$title, [string]$body, [string]$rightMenu) {
  $safeTitle = [Net.WebUtility]::HtmlEncode($title)
  return @"
<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <base href="../">
  <title>AVA_KCCT本部　クランHP - $safeTitle</title>
  <meta name="description" content="AVA_KCCT本部 クランHPのミラー">
  <link rel="stylesheet" href="mirror.css">
</head>
<body id="atwiki-jp">
  <header id="header">
    <h1><a href="pages/1.html">AVA_KCCT本部　クランHP</a></h1>
    <h2><a href="pages/$id.html">$safeTitle</a></h2>
  </header>
  <div id="wrapper">
    <main id="contents">
      <article id="wikibody" class="box">
$body
      </article>
      <div id="body_footer"><a href="#header">ページ上部へ</a></div>
    </main>
    <nav id="menubar" class="menu" aria-label="メニュー">
$(Get-MenuHtml)
    </nav>
    <aside id="rightbar">
$rightMenu
    </aside>
  </div>
  <footer id="footer">AVA_KCCT本部　クランHP mirror</footer>
</body>
</html>
"@
}

$feed = [xml](Get-Content -LiteralPath $RssFile -Raw -Encoding UTF8)
$feedBodies = @{}
foreach ($item in $feed.RDF.item) {
  $match = [regex]::Match([string]$item.link, 'pages/(\d+)')
  if (-not $match.Success) { continue }
  $id = [int]$match.Groups[1].Value
  $description = [string]$item.description
  if ($description -notmatch '<[a-z][\s\S]*>') { $description = Convert-WikiText $description $id }
  $feedBodies[$id] = $description
}

# The public RSS only contains recently updated pages. AtWiki's public backup
# source provides the complete latest saved body for older menu pages.
if ($BackupDirectory -and (Test-Path -LiteralPath $BackupDirectory)) {
  foreach ($entry in $pageTitles.GetEnumerator()) {
    $id = [int]$entry.Key
    $backupFile = Join-Path $BackupDirectory "$id.html"
    if (-not (Test-Path -LiteralPath $backupFile)) { continue }
    $backupHtml = Get-Content -LiteralPath $backupFile -Raw -Encoding UTF8
    $sourceMatch = [regex]::Match($backupHtml, '<pre\s+class="cmd_backup"[^>]*>([\s\S]*?)</pre>', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($sourceMatch.Success) {
      $source = [Net.WebUtility]::HtmlDecode($sourceMatch.Groups[1].Value).Trim()
      if ($source -notmatch '<[a-z][\s\S]*>') { $source = Convert-WikiText $source $id }
      if ($source) { $feedBodies[$id] = $source }
    }
  }
}

$unavailable = @{
  12 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
  14 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
  15 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
  18 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
  20 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
  23 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
  24 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
  27 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
  30 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
  31 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
  33 = "元サイトでメンバーまたは管理者のみに閲覧が制限されており、公開バックアップも存在しないため本文を取得できません。"
}
foreach ($entry in $unavailable.GetEnumerator()) {
  if (-not $feedBodies.ContainsKey($entry.Key)) {
    $missingTitle = $pageTitles[[int]$entry.Key]
    $feedBodies[$entry.Key] = "<h2>$([Net.WebUtility]::HtmlEncode($missingTitle))</h2><p>$([Net.WebUtility]::HtmlEncode($entry.Value))</p>"
  }
}

$rightMenu = if ($feedBodies.ContainsKey(3)) { $feedBodies[3] } else { '<h3>右メニュー</h3>' }
$script:leftMenuHtml = if ($feedBodies.ContainsKey(2)) { $feedBodies[2] } else { Get-MenuHtml }
foreach ($localId in $pageTitles.Keys) {
  $script:leftMenuHtml = $script:leftMenuHtml -replace "(?i)(?:https?:)?//(?:(?:www50|w)\.)?atwiki\.jp/ava_kccthnb/pages/$localId\.html", "pages/$localId.html"
}
$script:leftMenuHtml = $script:leftMenuHtml -replace '(?i)(?:https?:)?//(?:www50\.)?atwiki\.jp/ava_kccthnb/\?page=%E5%8F%B3%E3%83%A1%E3%83%8B%E3%83%A5%E3%83%BC', 'pages/3.html'
foreach ($entry in $pageTitles.GetEnumerator()) {
  $id = [int]$entry.Key
  $body = if ($feedBodies.ContainsKey($id)) { $feedBodies[$id] } else { "<h2>$([Net.WebUtility]::HtmlEncode($entry.Value))</h2>" }
  foreach ($localId in $pageTitles.Keys) {
    $body = $body -replace "(?i)(?:https?:)?//(?:(?:www50|w)\.)?atwiki\.jp/ava_kccthnb/pages/$localId\.html", "pages/$localId.html"
  }
  $body = $body -replace '(?i)(?:https?:)?//(?:www50\.)?atwiki\.jp/ava_kccthnb/\?page=%E5%8F%B3%E3%83%A1%E3%83%8B%E3%83%A5%E3%83%BC', 'pages/3.html'
  $html = Get-PageHtml $id $entry.Value $body $rightMenu
  $html = $html.Replace("`r`n", "`n").Replace("`r", "`n")
  [IO.File]::WriteAllText((Join-Path $pagesDirectory "$id.html"), $html, [Text.UTF8Encoding]::new($false))
}

Copy-Item (Join-Path $pagesDirectory "1.html") (Join-Path $projectRoot "index.html") -Force
$indexPath = Join-Path $projectRoot "index.html"
$indexHtml = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8).Replace('<base href="../">', '<base href="./">')
[IO.File]::WriteAllText($indexPath, $indexHtml, [Text.UTF8Encoding]::new($false))
Write-Host "Built $($pageTitles.Count) menu pages."
