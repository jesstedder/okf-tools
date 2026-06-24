#!/usr/bin/env pwsh
# Validate an OKF bundle for structural issues and broken links.
param(
    [Parameter(Mandatory)][string]$Bundle,
    [switch]$Strict
)
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'lib/okf_lib.ps1')

$root = [System.IO.Path]::GetFullPath($Bundle)
if (-not (Test-Path $root -PathType Container)) {
    Write-Error "bundle path is not a directory: $root"
    exit 1
}

$findings = 0
$concepts = @(Get-OkfConcepts $root)

# Detect case-insensitive ID collisions
$seenLower = @{}
foreach ($cid in $concepts) {
    $lower = $cid.ToLower()
    if ($seenLower.ContainsKey($lower)) {
        Write-Host "ERROR: [$cid] CONFLICTING_ID — duplicates concept ID (case-insensitive collision)"
        $findings++
    } else {
        $seenLower[$lower] = $cid
    }
}

# Build lookup map for link resolution
$idMap = @{}
$basenameMap = @{}
foreach ($cid in $concepts) {
    $idMap[$cid.ToLower()] = $cid
    $base = ($cid -split '/')[-1].ToLower()
    if (-not $basenameMap.ContainsKey($base)) { $basenameMap[$base] = $cid }
}

$mdLinkRe   = [regex]'!?\[([^\]]*)\]\(([^)]+)\)'
$wikiLinkRe = [regex]'\[\[([^\]]+)\]\]'

foreach ($cid in $concepts) {
    $file = Join-Path $root "$cid.md"

    if (-not (Test-OkfFmHasType $file)) {
        Write-Host "ERROR: [$cid] Missing or blank required frontmatter field: type"
        $findings++
        continue
    }

    $body = Get-OkfFmBody $file

    # Check markdown links
    foreach ($m in $mdLinkRe.Matches($body)) {
        $target = $m.Groups[2].Value.Trim() -replace '<|>','' -split ' ' | Select-Object -First 1
        $target = ($target -split '#')[0]
        if ($target -match '^(https?://|mailto:|file://|/|#)') { continue }
        if ($target -eq '') { continue }

        $srcDir = if ($cid -match '/') { $cid.Substring(0, $cid.LastIndexOf('/')) } else { '' }
        $combined = if ($srcDir) { "$srcDir/$($target -replace '\.md$','')" } else { $target -replace '\.md$','' }
        $norm = Resolve-OkfNormalizePath $combined

        if (-not $idMap.ContainsKey($norm)) {
            Write-Host "ERROR: [$cid] BROKEN_LINK: $($m.Value) -> $target"
            $findings++
        }
    }

    # Check wikilinks
    foreach ($m in $wikiLinkRe.Matches($body)) {
        $inner  = $m.Groups[1].Value
        $target = ($inner -split '\|')[0].Trim()
        if ($target -match '^https?://') { continue }

        $lt = ($target.ToLower() -replace ' ','-') -replace '\.md$',''
        $found = $idMap.ContainsKey($lt) -or $basenameMap.ContainsKey($lt)
        if (-not $found) {
            Write-Host "ERROR: [$cid] BROKEN_LINK: $($m.Value) -> $target"
            $findings++
        }
    }
}

if ($findings -eq 0) {
    Write-Host "OK: $root is a valid OKF bundle"
    exit 0
} else {
    Write-Host ""
    Write-Host "$findings finding(s)"
    exit 1
}
