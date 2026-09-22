#!/usr/bin/env pwsh
#
# Remove links that point into this repo. Only removes entries whose target is
# inside the repo -- anything else (your own skills, other marketplaces) is left alone.
#
#   .\scripts\uninstall.ps1            remove links
#   .\scripts\uninstall.ps1 -DryRun    show what would be removed

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Test-PointsIntoRepo {
    param([string]$TargetFull)
    return ($TargetFull -eq $Repo) -or $TargetFull.StartsWith("$Repo\")
}

function Test-HardLinkIntoRepo {
    param([string]$Path)
    $drive = Split-Path $Path -Qualifier
    try {
        $links = fsutil hardlink list $Path 2>$null
    } catch {
        return $false
    }
    foreach ($l in $links) {
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        $full = Join-Path $drive $l.TrimStart('\')
        if (Test-PointsIntoRepo -TargetFull $full) { return $true }
    }
    return $false
}

$removed = 0
$dirs = @(
    (Join-Path $HOME '.claude\skills'),
    (Join-Path $HOME '.codex\skills'),
    (Join-Path $HOME '.claude\agents'),
    (Join-Path $HOME '.claude'),
    (Join-Path $HOME '.codex')
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem -Path $dir -Force | ForEach-Object {
        $entry = $_.FullName

        if ($_.LinkType) {
            $target = $_.Target
            if ($target -is [array]) { $target = $target[0] }
            $targetFull = $target
            try { $targetFull = (Resolve-Path -LiteralPath $target -ErrorAction Stop).Path } catch {}
            if (Test-PointsIntoRepo -TargetFull $targetFull) {
                if ($DryRun) {
                    Write-Host "  would remove: $entry" -ForegroundColor DarkGray
                } else {
                    Remove-Item -LiteralPath $entry -Force -Recurse
                    Write-Host "  - $entry" -ForegroundColor Green
                }
                $script:removed++
            }
        } elseif (-not $_.PSIsContainer -and (Test-HardLinkIntoRepo -Path $entry)) {
            if ($DryRun) {
                Write-Host "  would remove: $entry" -ForegroundColor DarkGray
            } else {
                Remove-Item -LiteralPath $entry -Force
                Write-Host "  - $entry" -ForegroundColor Green
            }
            $script:removed++
        }
    }
}

if ($removed -eq 0) {
    Write-Host 'Nothing installed from this repo.'
} elseif ($DryRun) {
    Write-Host "$removed link(s) would be removed."
} else {
    Write-Host "Removed $removed link(s). Backups, if any, are under ~\.GR-ai-agents-backup\."
}
