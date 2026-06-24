#!/usr/bin/env pwsh
# Answer a question from an OKF bundle by ranking relevant concepts.
param(
    [Parameter(Mandatory)][string]$Bundle,
    [Parameter(Mandatory)][string]$Query,
    [int]$Max = 10
)
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'lib/okf_lib.ps1')

$root = [System.IO.Path]::GetFullPath($Bundle)

$stopwords = [System.Collections.Generic.HashSet[string]]@(
    'a','an','the','is','are','was','were','be','been','being',
    'to','of','and','or','in','on','at','for','with','from',
    'as','it','its','this','that','these','those','how','what',
    'when','where','why','who','which','can','do','does','did',
    'i','you','we','they','my','your','our','their'
)

function Get-Tokens([string]$Text) {
    [regex]::Matches($Text.ToLower(), '[a-zA-Z0-9_+\-]+') |
        ForEach-Object { $_.Value } |
        Where-Object { -not $stopwords.Contains($_) }
}

$queryTerms = [System.Collections.Generic.HashSet[string]](Get-Tokens $Query)
$phrase     = $Query.ToLower()

function Get-ConceptScore($Concept) {
    $score = 0
    $fields = @(
        @{ Text = $Concept.title;                  Weight = 4 }
        @{ Text = ($Concept.description ?? '');    Weight = 3 }
        @{ Text = ($Concept.tags -join ' ');       Weight = 3 }
        @{ Text = $Concept.type;                   Weight = 2 }
        @{ Text = $Concept.body_snippet;           Weight = 1 }
    )
    foreach ($f in $fields) {
        $tokens = Get-Tokens $f.Text
        $matches_ = ($tokens | Where-Object { $queryTerms.Contains($_) }).Count
        if ($f.Text.ToLower().Contains($phrase)) { $matches_ += 5 }
        $score += $matches_ * $f.Weight
    }
    return $score
}

$hotFile = Join-Path $root 'hot.md'
$idxFile = Join-Path $root 'index.md'
$hotExists   = (Test-Path $hotFile)  ? 'true' : 'false'
$indexExists = (Test-Path $idxFile)  ? 'true' : 'false'

$results = @()
foreach ($cid in (Get-OkfConcepts $root)) {
    $file = Join-Path $root "$cid.md"
    if (-not (Test-OkfFmHasType $file)) { continue }

    $title = Get-OkfFmField $file 'title'
    if (-not $title) {
        $title = ($cid -split '/')[-1] -replace '-',' '
    }
    $desc  = Get-OkfFmField $file 'description'
    $type  = Get-OkfFmField $file 'type'
    $tags  = @(Get-OkfFmTags $file)
    $body  = Get-OkfFmBody $file

    $concept = [PSCustomObject]@{
        id           = $cid
        title        = $title
        description  = $desc
        type         = $type
        tags         = $tags
        body_snippet = $body.Substring(0, [Math]::Min(2000, $body.Length))
    }

    $score = Get-ConceptScore $concept
    if ($score -gt 0) {
        $results += [PSCustomObject]@{
            id          = $cid
            title       = $title
            type        = $type
            description = $desc
            tags        = $tags
            score       = $score
        }
    }
}

$sorted = $results | Sort-Object -Property score -Descending | Select-Object -First $Max

[ordered]@{
    bundle       = $root
    query        = $Query
    hot_exists   = ($hotExists -eq 'true')
    index_exists = ($indexExists -eq 'true')
    results      = @($sorted)
} | ConvertTo-Json -Depth 5
