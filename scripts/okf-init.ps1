#!/usr/bin/env pwsh
# Scaffold a new OKF bundle.
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Name
)
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'lib/okf_lib.ps1')

$target = [System.IO.Path]::GetFullPath($Path)

if ((Test-Path $target) -and (Get-ChildItem $target -Force).Count -gt 0) {
    Write-Error "error: target directory is not empty: $target"
    exit 1
}

if (-not $Name) { $Name = Split-Path $target -Leaf }

$today = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
$now   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss+00:00')

New-Item -ItemType Directory -Path $target -Force | Out-Null

# index.md
@"
# $Name

Bundle overview. Add links to concepts below.
"@ | Set-Content (Join-Path $target 'index.md') -Encoding UTF8

# log.md
@"
# Log

## $today
- Created OKF bundle.
"@ | Set-Content (Join-Path $target 'log.md') -Encoding UTF8

# hot.md
@'
# Hot

Recent context and quick notes go here. This file is read first by `okf-query`.
'@ | Set-Content (Join-Path $target 'hot.md') -Encoding UTF8

# concepts/starter-concept.md
New-Item -ItemType Directory -Path (Join-Path $target 'concepts') -Force | Out-Null
Write-OkfConcept `
    -Dest (Join-Path $target 'concepts/starter-concept.md') `
    -Type 'Concept' `
    -Title "$Name starter concept" `
    -Description 'An example concept to get started.' `
    -Resource '' `
    -Tags @('example') `
    -Timestamp $now `
    -Body "# Starter Concept`n`nReplace this with real content."

# .okf/types.md
New-Item -ItemType Directory -Path (Join-Path $target '.okf') -Force | Out-Null
@'
# OKF Type Registry

Default types used in this bundle:
- Concept
- Entity
- Guide
- Reference
- Source
- Decision
- Question
- Log
'@ | Set-Content (Join-Path $target '.okf/types.md') -Encoding UTF8

Write-Host "Created OKF bundle at $target"
