#!/usr/bin/env pwsh
#
# Remove links that point into this repo. Only removes entries whose target is
# inside the repo -- anything else (your own skills, other marketplaces) is left alone.
#
#   .\scripts\uninstall.ps1            remove links
#   .\scripts\uninstall.ps1 -DryRun    show what would be removed
#   $env:CLAUDE_BIN = '<path>'           use this claude CLI for the plugin step
#
# Also uninstalls the fast-jev-compaction plugin and its marketplace through the
# claude CLI, which deletes the plugin's saved options. The plugins\ checkout stays.

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

# --- fast-jev-compaction plugin -----------------------------------------------
function Get-ClaudeCli {
    if ($env:CLAUDE_BIN) {
        if (Test-Path -LiteralPath $env:CLAUDE_BIN) { return $env:CLAUDE_BIN }
        return $null
    }
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$PluginId = 'fast-jev-compaction@gr-fast-jev-compaction'
$Marketplace = 'gr-fast-jev-compaction'
$cli = Get-ClaudeCli
if (-not $cli) {
    $b = if ($env:CLAUDE_BIN) { $env:CLAUDE_BIN } else { 'unset' }
    Write-Host "claude CLI not found (CLAUDE_BIN=$b) -- plugin left installed; set CLAUDE_BIN=<path to claude>"
} elseif ($DryRun) {
    Write-Host "  would: $cli plugin uninstall $PluginId (if installed)" -ForegroundColor DarkGray
    Write-Host "  would: $cli plugin marketplace remove $Marketplace (if present; drops the plugin's saved options)" -ForegroundColor DarkGray
} else {
    # Removing something absent exits nonzero, so check each list first.
    $plugins = (& $cli plugin list --json) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'claude plugin list failed' }
    if ($plugins.Contains("`"$PluginId`"")) {
        & $cli plugin uninstall $PluginId
        if ($LASTEXITCODE -ne 0) { throw 'claude plugin uninstall failed' }
    }
    $mkts = (& $cli plugin marketplace list --json) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'claude plugin marketplace list failed' }
    if ($mkts.Contains("`"$Marketplace`"")) {
        Write-Host "removing marketplace $Marketplace (this deletes the plugin's saved options)"
        & $cli plugin marketplace remove $Marketplace
        if ($LASTEXITCODE -ne 0) { throw 'claude plugin marketplace remove failed' }
    }
}

if ($removed -eq 0) {
    Write-Host 'Nothing installed from this repo.'
} elseif ($DryRun) {
    Write-Host "$removed link(s) would be removed."
} else {
    Write-Host "Removed $removed link(s). Backups, if any, are under ~\.GR-ai-agents-backup\."
}
