# OKF shared PowerShell library.
# Dot-source with: . (Join-Path $PSScriptRoot 'lib/okf_lib.ps1')

$OKF_RESERVED = @('index.md','log.md','hot.md')

function Get-OkfFmField([string]$File, [string]$Field) {
    $lines = Get-Content $File
    if ($lines[0] -ne '---') { return $null }
    $in_fm = $false
    foreach ($line in $lines) {
        if ($line -eq '---') {
            if (-not $in_fm) { $in_fm = $true; continue }
            else { break }
        }
        if (-not $in_fm) { continue }
        if ($line -match "^$([regex]::Escape($Field)):\s*(.*)$") {
            $val = $Matches[1].Trim().Trim('"').Trim("'")
            if ($val -ne 'null') { return $val }
            return $null
        }
    }
    return $null
}

function Get-OkfFmTags([string]$File) {
    $lines = Get-Content $File
    if ($lines[0] -ne '---') { return @() }
    $in_fm = $false; $in_tags = $false; $tags = @()
    foreach ($line in $lines) {
        if ($line -eq '---') {
            if (-not $in_fm) { $in_fm = $true; continue }
            else { break }
        }
        if (-not $in_fm) { continue }
        if ($line -match '^tags:\s*\[(.+)\]') {
            return $Matches[1] -split ',' | ForEach-Object {
                $_.Trim().Trim('"').Trim("'")
            } | Where-Object { $_ -ne '' }
        }
        if ($line -match '^tags:') { $in_tags = $true; continue }
        if ($in_tags) {
            if ($line -match '^\s*-\s*(.+)') {
                $tags += $Matches[1].Trim().Trim('"').Trim("'")
            } elseif ($line -match '^[^\s-]') { $in_tags = $false }
        }
    }
    return $tags
}

function Get-OkfFmBody([string]$File) {
    $lines = Get-Content $File -Raw
    if (-not $lines.StartsWith('---')) { return $lines }
    # Split on the second ---
    $idx = $lines.IndexOf("`n---", 4)
    if ($idx -lt 0) { return $lines }
    $body = $lines.Substring($idx + 4).TrimStart("`r", "`n")
    return $body
}

function Test-OkfFmHasType([string]$File) {
    $t = Get-OkfFmField $File 'type'
    return ($null -ne $t -and $t -ne '')
}

function ConvertTo-OkfSlug([string]$Text) {
    $slug = $Text.ToLower()
    $slug = [regex]::Replace($slug, '[^a-z0-9_-]+', '-')
    $slug = $slug.Trim('-')
    return $slug
}

function Resolve-OkfNormalizePath([string]$Path) {
    $parts = @()
    foreach ($part in $Path.Replace('\','/') -split '/') {
        if ($part -eq '..') { if ($parts.Count -gt 0) { $parts = $parts[0..($parts.Count-2)] } }
        elseif ($part -and $part -ne '.') { $parts += $part }
    }
    return ($parts -join '/').ToLower()
}

function Get-OkfRelativePath([string]$SourceId, [string]$TargetId) {
    if ($SourceId -notmatch '/') { return "$TargetId.md" }
    $sdir = $SourceId.Substring(0, $SourceId.LastIndexOf('/'))
    $sParts = $sdir -split '/'
    $tParts = $TargetId -split '/'
    $ns = $sParts.Count; $nt = $tParts.Count
    $i = 0
    while ($i -lt $ns -and $i -lt ($nt-1) -and $sParts[$i] -eq $tParts[$i]) { $i++ }
    $rel = @()
    for ($j=$i; $j -lt $ns; $j++) { $rel += '..' }
    for ($j=$i; $j -lt $nt-1; $j++) { $rel += $tParts[$j] }
    $relStr = if ($rel.Count -gt 0) { ($rel -join '/') + '/' } else { '' }
    return "$relStr$($tParts[-1]).md"
}

function Get-OkfConcepts([string]$BundleRoot) {
    $root = Resolve-Path $BundleRoot
    Get-ChildItem -Path $root -Recurse -Filter '*.md' | ForEach-Object {
        $rel = $_.FullName.Substring($root.Path.Length + 1).Replace('\','/')
        $base = $_.Name
        if ($OKF_RESERVED -contains $base.ToLower()) { return }
        $parts = $rel -split '/'
        # Skip hidden dirs
        foreach ($part in $parts[0..($parts.Count-2)]) {
            if ($part.StartsWith('.')) { return }
        }
        $rel -replace '\.md$',''
    } | Sort-Object
}

function Get-OkfExtractTitle([string]$Body, [string]$Stem) {
    $m = [regex]::Match($Body, '(?m)^#\s+(.+)$')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $Stem.Replace('-',' ').Replace('_',' ')
}

function Get-OkfExtractDescription([string]$Body) {
    foreach ($line in $Body -split "`n") {
        $t = $line.Trim()
        if (-not $t) { continue }
        if ($t.StartsWith('#')) { continue }
        return $t.Substring(0, [Math]::Min(200, $t.Length))
    }
    return $null
}

function Get-OkfExtractHashtags([string]$Body) {
    [regex]::Matches($Body, '#([A-Za-z0-9_-]+)') | ForEach-Object { $_.Groups[1].Value }
}

function ConvertTo-OkfYamlStr([string]$Val) {
    if (-not $Val) { return 'null' }
    $needQuote = $Val -match '^[\s:&#*!|>''"%@`{}\[\]]' -or
                 $Val -match '\s$' -or
                 $Val -match ': ' -or
                 $Val -in @('null','true','false','yes','no','on','off')
    if ($needQuote) {
        $escaped = $Val.Replace("'", "''")
        return "'$escaped'"
    }
    return $Val
}

function Write-OkfConcept {
    param(
        [string]$Dest,
        [string]$Type,
        [string]$Title,
        [string]$Description,
        [string]$Resource,
        [string[]]$Tags,
        [string]$Timestamp,
        [string]$Body
    )
    $dir = Split-Path $Dest -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine("type: $(ConvertTo-OkfYamlStr $Type)")
    [void]$sb.AppendLine("title: $(ConvertTo-OkfYamlStr $Title)")
    [void]$sb.AppendLine("description: $(ConvertTo-OkfYamlStr $Description)")
    if ($Resource) { [void]$sb.AppendLine("resource: $(ConvertTo-OkfYamlStr $Resource)") }
    if ($Tags -and $Tags.Count -gt 0) {
        [void]$sb.AppendLine('tags:')
        foreach ($t in $Tags) { [void]$sb.AppendLine("- $t") }
    } else {
        [void]$sb.AppendLine('tags: []')
    }
    [void]$sb.AppendLine("timestamp: $Timestamp")
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('')
    [void]$sb.Append($Body)

    [System.IO.File]::WriteAllText($Dest, $sb.ToString(), [System.Text.Encoding]::UTF8)
}

function Invoke-OkfRewriteWikilinks([string]$Content, [string]$SourceId, [string[]]$ExistingIds) {
    # Build lookup: lowercase → canonical
    $ids = @{}; $basenames = @{}
    foreach ($id in $ExistingIds) {
        $lower = ($id.ToLower() -replace ' ','-')
        $ids[$lower] = $id
        $base = ($id -split '/')[-1].ToLower() -replace ' ','-'
        if (-not $basenames.ContainsKey($base)) { $basenames[$base] = $id }
    }

    $result = [regex]::Replace($Content, '\[\[([^\]]+)\]\]', {
        param($m)
        $inner = $m.Groups[1].Value
        $pipe  = $inner.IndexOf('|')
        if ($pipe -ge 0) {
            $target = $inner.Substring(0, $pipe).Trim()
            $label  = $inner.Substring($pipe+1).Trim()
        } else {
            $target = $inner.Trim()
            $label  = $target
        }
        $lt = ($target.ToLower() -replace ' ','-')
        $resolved = $null
        if ($ids.ContainsKey($lt)) { $resolved = $ids[$lt] }
        elseif ($basenames.ContainsKey($lt)) { $resolved = $basenames[$lt] }

        if ($resolved) {
            $rel = Get-OkfRelativePath $SourceId $resolved
            return "[$label]($rel)"
        }
        return $m.Value
    })
    return $result
}
