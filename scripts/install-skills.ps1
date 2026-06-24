#!/usr/bin/env pwsh
# Install OKF skills by symlinking them into agent skill directories.
[CmdletBinding()]
param(
    [switch]$Hermes,
    [switch]$Claude,
    [switch]$OpenCode,
    [switch]$Copilot,
    [switch]$Global,   # claude + opencode + copilot
    [switch]$All       # hermes + global
)

$repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..')
$skillsSrc  = Join-Path $repoRoot 'skills'
$skillPrefix = 'okf-'

# Default to hermes if no flags given
$none = -not ($Hermes -or $Claude -or $OpenCode -or $Copilot -or $Global -or $All)
if ($none)   { $Hermes = $true }
if ($Global) { $Claude = $true; $OpenCode = $true; $Copilot = $true }
if ($All)    { $Hermes = $true; $Claude = $true; $OpenCode = $true; $Copilot = $true }

function Install-To([string]$Dest) {
    Write-Host "Installing to $Dest"
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null

    # Remove stale symlinks / junctions
    Get-ChildItem -Path $Dest -Filter "$skillPrefix*" -Force | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force
    }

    # Create a symlink (junction on Windows, symlink on Unix) for each skill
    Get-ChildItem -Path $skillsSrc -Directory -Filter "$skillPrefix*" | ForEach-Object {
        $target = Join-Path $Dest $_.Name
        if ($IsWindows) {
            New-Item -ItemType Junction -Path $target -Target $_.FullName | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName | Out-Null
        }
        Write-Host "  $($_.Name)"
    }
}

if ($Hermes)   { Install-To (Join-Path $HOME '.hermes/skills') }
if ($Claude)   { Install-To (Join-Path $HOME '.claude/skills') }
if ($OpenCode) { Install-To (Join-Path $HOME '.opencode/skills') }
if ($Copilot)  { Install-To (Join-Path $HOME '.copilot/skills') }

Write-Host 'Done.'
