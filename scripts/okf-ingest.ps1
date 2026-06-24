#!/usr/bin/env pwsh
# Ingest a source file or URL into an OKF bundle as a typed concept.
param(
    [Parameter(Mandatory)][string]$Bundle,
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Type,
    [string]$Id,
    [string]$Title,
    [string]$Tags
)
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'lib/okf_lib.ps1')

$root = [System.IO.Path]::GetFullPath($Bundle)
$now  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss+00:00')

function ConvertTo-Markdown([string]$Html) {
    if (Get-Command pandoc -ErrorAction SilentlyContinue) {
        return $Html | pandoc -f html -t markdown --wrap=none 2>$null
    }
    # Basic fallback: strip tags
    return [regex]::Replace($Html, '<[^>]+>', '') -replace '(?m)^\s*$\n',''
}

# Load source content
$body = ''
$sourceLabel = $Source
if ($Source -match '^https?://') {
    try {
        $resp = Invoke-WebRequest -Uri $Source -UserAgent 'okf-ingest/0.1' -TimeoutSec 30
        $ct   = $resp.Headers['Content-Type'] ?? ''
        $body = $resp.Content
        if ($ct -match 'html') { $body = ConvertTo-Markdown $body }
    } catch {
        Write-Error "Failed to fetch URL: $Source — $_"
        exit 1
    }
} else {
    $srcPath = [System.IO.Path]::GetFullPath($Source)
    if (-not (Test-Path $srcPath)) {
        Write-Error "source not found: $srcPath"
        exit 1
    }
    $body = Get-Content $srcPath -Raw
    $sourceLabel = $srcPath
    if ($srcPath -match '\.(html?|htm)$') { $body = ConvertTo-Markdown $body }
}

# Idempotency: find existing concept with same resource
$existingPath = $null
foreach ($cid in (Get-OkfConcepts $root)) {
    $f = Join-Path $root "$cid.md"
    $res = Get-OkfFmField $f 'resource'
    if ($res -eq $Source) { $existingPath = $f; break }
}

$isUpdate = $false
if ($existingPath) {
    $targetPath = $existingPath
    $isUpdate   = $true
} else {
    if (-not $Id) {
        $stem = if ($Title) { $Title }
                elseif ($Source -match '^https?://') {
                    $uri = [System.Uri]$Source
                    ($uri.Segments[-1] -replace '\?.*','').Trim('/')
                } else { [System.IO.Path]::GetFileNameWithoutExtension($Source) }
        if (-not $stem) { $stem = 'ingested' }
        $slug = ConvertTo-OkfSlug $stem
        $Id   = if ($Type.ToLower() -eq 'source') { "sources/$slug" } else { "$($Type.ToLower())s/$slug" }
    }
    $targetPath = Join-Path $root "$Id.md"
}

$finalTitle = if ($Title) { $Title } else { Get-OkfExtractTitle $body ([System.IO.Path]::GetFileNameWithoutExtension($targetPath) -replace '-',' ') }
$finalDesc  = Get-OkfExtractDescription $body
$tagArray   = if ($Tags) { $Tags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } } else { @() }

Write-OkfConcept `
    -Dest       $targetPath `
    -Type       $Type `
    -Title      $finalTitle `
    -Description ($finalDesc ?? '') `
    -Resource   $Source `
    -Tags       $tagArray `
    -Timestamp  $now `
    -Body       $body

$conceptRel = $targetPath.Substring($root.Length + 1).Replace('\','/')

# Update index.md
$indexFile = Join-Path $root 'index.md'
if (-not (Test-Path $indexFile)) {
    "# $(Split-Path $root -Leaf)`n`n" | Set-Content $indexFile -Encoding UTF8
}
$indexContent = Get-Content $indexFile -Raw
$linkLine = "- [$finalTitle]($conceptRel)"
if ($indexContent -notmatch [regex]::Escape($conceptRel) -and
    $indexContent -notmatch [regex]::Escape($finalTitle)) {
    ($indexContent.TrimEnd() + "`n$linkLine`n") | Set-Content $indexFile -Encoding UTF8
}

# Append to log.md
$logFile = Join-Path $root 'log.md'
if (-not (Test-Path $logFile)) { "# Log`n`n" | Set-Content $logFile -Encoding UTF8 }
$logContent = Get-Content $logFile -Raw
$entry = "## $now`n- Ingested [$finalTitle]($conceptRel) from ``$sourceLabel```n`n"
($logContent.TrimEnd() + "`n$entry") | Set-Content $logFile -Encoding UTF8

$action = if ($isUpdate) { 'Updated' } else { 'Created' }
Write-Host "${action}: $targetPath"
