#!/usr/bin/env pwsh
# Convert a claude-obsidian vault to an OKF bundle.
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Dest,
    [switch]$DryRun,
    [switch]$KeepWikilinks
)
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'lib/okf_lib.ps1')

$srcRoot  = [System.IO.Path]::GetFullPath($Source)
$destRoot = [System.IO.Path]::GetFullPath($Dest)

if (-not $DryRun -and (Test-Path $destRoot) -and (Get-ChildItem $destRoot -Force).Count -gt 0) {
    Write-Error "destination is not empty: $destRoot"
    exit 1
}

$folderTypeMap = @{
    concepts   = 'Concept'
    entities   = 'Entity'
    guides     = 'Guide'
    homelab    = 'Decision'
    meta       = 'Decision'
    questions  = 'Question'
    references = 'Reference'
    sources    = 'Source'
}

function Get-FolderType([string]$Folder) {
    $folderTypeMap[$Folder] ?? 'Concept'
}

function Get-FmBody([string]$Text) {
    if (-not $Text.TrimStart().StartsWith('---')) { return $Text }
    $parts = $Text -split '---', 3
    if ($parts.Count -ge 3) { return $parts[2].TrimStart("`r","`n") }
    return $Text
}

# Use wiki/ subdirectory if present
$wikiRoot = if (Test-Path (Join-Path $srcRoot 'wiki') -PathType Container) {
    Join-Path $srcRoot 'wiki'
} else { $srcRoot }

$reserved = @('index.md','log.md','hot.md')

# Phase 1: discover .md files and compute concept IDs
$entries = @()
Get-ChildItem -Path $wikiRoot -Recurse -Filter '*.md' | Sort-Object FullName | ForEach-Object {
    $rel  = $_.FullName.Substring($wikiRoot.Length + 1).Replace('\','/')
    $base = $_.Name
    if ($reserved -contains $base.ToLower()) { return }

    # Skip hidden dirs
    $parts = $rel -split '/'
    foreach ($part in $parts[0..($parts.Count-2)]) {
        if ($part.StartsWith('.')) { return }
    }

    $dir  = if ($rel -match '/') { $rel.Substring(0, $rel.LastIndexOf('/')) } else { '' }
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    $slug = ConvertTo-OkfSlug $stem
    $cid  = if ($dir) { "$dir/$slug" } else { $slug }

    $entries += [PSCustomObject]@{ Path = $_.FullName; RelDir = $dir; ConceptId = $cid; Stem = $stem }
}

$existingIds = @($entries | ForEach-Object { $_.ConceptId })
$total = $entries.Count
$shown = 0

# Phase 2: convert each concept
foreach ($entry in $entries) {
    $text = Get-Content $entry.Path -Raw
    $body = Get-FmBody $text

    $topFolder = ($entry.RelDir -split '/')[0]
    $ctype     = Get-FolderType $topFolder

    $title  = Get-OkfExtractTitle $body $entry.Stem
    $desc   = Get-OkfExtractDescription $body
    $htags  = @(Get-OkfExtractHashtags $body)
    $mtime  = (Get-Item $entry.Path).LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ss+00:00')

    if (-not $KeepWikilinks) {
        $body = Invoke-OkfRewriteWikilinks $body $entry.ConceptId $existingIds
    }

    $destRel  = if ($entry.RelDir) { "$($entry.RelDir)/$(ConvertTo-OkfSlug $entry.Stem).md" } else { "$(ConvertTo-OkfSlug $entry.Stem).md" }
    $destPath = Join-Path $destRoot $destRel

    if ($shown -lt 10) {
        $verb = if ($DryRun) { 'WOULD CREATE' } else { 'CREATED' }
        Write-Host "${verb}: $destPath"
        $shown++
    }

    if (-not $DryRun) {
        Write-OkfConcept `
            -Dest        $destPath `
            -Type        $ctype `
            -Title       $title `
            -Description ($desc ?? '') `
            -Resource    '' `
            -Tags        $htags `
            -Timestamp   $mtime `
            -Body        $body
    }
}

$remaining = $total - 10
if ($remaining -gt 0) { Write-Host "... and $remaining more" }

if (-not $DryRun) {
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null

    $rewrite = { param($txt, $sid) Invoke-OkfRewriteWikilinks $txt $sid $existingIds }

    foreach ($fname in @('index.md','log.md','hot.md')) {
        $src = Join-Path $wikiRoot $fname
        $dst = Join-Path $destRoot $fname
        if (Test-Path $src) {
            $content = Get-Content $src -Raw
            if (-not $KeepWikilinks) { $content = & $rewrite $content '' }
            [System.IO.File]::WriteAllText($dst, $content, [System.Text.Encoding]::UTF8)
        } elseif ($fname -eq 'index.md') {
            "# $(Split-Path $destRoot -Leaf)`n`nConverted from claude-obsidian vault.`n" |
                Set-Content $dst -Encoding UTF8
        } elseif ($fname -eq 'log.md') {
            "# Log`n`nConverted vault.`n" | Set-Content $dst -Encoding UTF8
        }
    }
}

Write-Host ""
Write-Host "Total concepts: $total"
