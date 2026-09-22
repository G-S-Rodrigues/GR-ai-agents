#!/usr/bin/env pwsh
#
# Install the Evo agent skills into your local harness by symlink (or, where Windows
# denies unprivileged symlinks, junction/hardlink), so a `git pull` in this repo updates
# every installed skill with no reinstall.
#
#   .\scripts\install.ps1                 install skills + agents + references
#   .\scripts\install.ps1 -DryRun         show what would change, touch nothing
#   .\scripts\install.ps1 -WithDrafts     also install skills\in-progress\*
#   .\scripts\install.ps1 -ClaudeOnly     skip the ~\.codex targets
#
# Existing real files/directories at a target path are moved into a timestamped
# backup directory, never deleted. Existing links are replaced.
#
# Directories are linked as symlinks when the process can create them (admin, or
# Developer Mode enabled), falling back to a junction otherwise. Files (agents\*.md)
# are linked as symlinks when possible, falling back to a hardlink. Junctions and
# hardlinks behave the same for this script's purpose: edit the repo file, the
# installed copy sees it immediately.

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$WithDrafts,
    [switch]$ClaudeOnly
)

$ErrorActionPreference = 'Stop'

$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = Join-Path $HOME ".GR-ai-agents-backup\$Timestamp"
$script:BackedUp = $false
$script:UsedHardLink = $false

function Write-Ok($msg)   { Write-Host "  + $msg" -ForegroundColor Green }
function Write-Same($msg) { Write-Host "  = $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  ~ $msg" -ForegroundColor Yellow }
function Write-Skip($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }

function Test-HardLinkMatches {
    param([string]$Dst, [string]$SrcFull)
    $drive = Split-Path $Dst -Qualifier
    try {
        $links = fsutil hardlink list $Dst 2>$null
    } catch {
        return $false
    }
    foreach ($l in $links) {
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        $full = Join-Path $drive $l.TrimStart('\')
        if ($full -eq $SrcFull) { return $true }
    }
    return $false
}

function Install-Link {
    param([string]$Src, [string]$Dst)

    $name = Split-Path $Dst -Leaf
    $srcFull = (Resolve-Path $Src).Path
    $isDir = (Get-Item $Src).PSIsContainer

    if (Test-Path -LiteralPath $Dst) {
        $item = Get-Item -LiteralPath $Dst -Force

        if ($item.LinkType) {
            # existing symlink or junction
            $target = $item.Target
            if ($target -is [array]) { $target = $target[0] }
            $targetFull = $target
            try { $targetFull = (Resolve-Path -LiteralPath $target -ErrorAction Stop).Path } catch {}
            if ($targetFull -eq $srcFull) {
                Write-Same "$name already linked"
                return
            }
            if (-not $DryRun) { Remove-Item -LiteralPath $Dst -Force -Recurse }
            Write-Warn "$name relinked (was $target)"
        } elseif (-not $isDir -and (Test-HardLinkMatches -Dst $Dst -SrcFull $srcFull)) {
            Write-Same "$name already linked"
            return
        } else {
            $rel = $Dst.Substring($HOME.Length).TrimStart('\')
            $backupPath = Join-Path $Backup $rel
            if (-not $DryRun) {
                New-Item -ItemType Directory -Force -Path (Split-Path $backupPath) | Out-Null
                Move-Item -LiteralPath $Dst -Destination $backupPath -Force
            }
            $script:BackedUp = $true
            Write-Warn "$name backed up, then linked"
        }
    } else {
        Write-Ok "$name linked"
    }

    if ($DryRun) { return }

    New-Item -ItemType Directory -Force -Path (Split-Path $Dst) | Out-Null

    if ($isDir) {
        try {
            New-Item -ItemType SymbolicLink -Path $Dst -Target $srcFull -ErrorAction Stop | Out-Null
        } catch {
            New-Item -ItemType Junction -Path $Dst -Target $srcFull | Out-Null
        }
    } else {
        try {
            New-Item -ItemType SymbolicLink -Path $Dst -Target $srcFull -ErrorAction Stop | Out-Null
        } catch {
            New-Item -ItemType HardLink -Path $Dst -Target $srcFull | Out-Null
            $script:UsedHardLink = $true
        }
    }
}

if ($DryRun) { Write-Host 'dry run -- nothing will be written' -ForegroundColor DarkGray }
Write-Host "repo: $Repo"

# --- targets ------------------------------------------------------------------
$SkillDirs = @((Join-Path $HOME '.claude\skills'))
$AgentDirs = @((Join-Path $HOME '.claude\agents'))
$RefDirs   = @((Join-Path $HOME '.claude\GR-references'))
if (-not $ClaudeOnly) {
    $SkillDirs += (Join-Path $HOME '.codex\skills')
    $RefDirs   += (Join-Path $HOME '.codex\GR-references')
}

# --- skills -------------------------------------------------------------------
Write-Host ''
Write-Host "skills ->  $($SkillDirs -join ', ')"
Get-ChildItem -Path (Join-Path $Repo 'skills') -Directory | Where-Object { $_.Name -ne 'in-progress' } | ForEach-Object {
    $skill = $_.FullName
    $name = $_.Name
    $skillMd = Join-Path $skill 'SKILL.md'
    if (-not (Test-Path $skillMd)) {
        Write-Skip "$name no SKILL.md, skipped"
        return
    }
    foreach ($d in $SkillDirs) { Install-Link -Src $skill -Dst (Join-Path $d $name) }
}

if ($WithDrafts) {
    Write-Host ''
    Write-Host 'drafts (skills\in-progress) ->'
    $draftsDir = Join-Path $Repo 'skills\in-progress'
    if (Test-Path $draftsDir) {
        Get-ChildItem -Path $draftsDir -Directory | ForEach-Object {
            $skill = $_.FullName
            $name = $_.Name
            if (-not (Test-Path (Join-Path $skill 'SKILL.md'))) { return }
            foreach ($d in $SkillDirs) { Install-Link -Src $skill -Dst (Join-Path $d $name) }
        }
    }
}

# --- agents (Claude subagents only) -------------------------------------------
Write-Host ''
Write-Host "agents ->  $($AgentDirs -join ', ')"
Get-ChildItem -Path (Join-Path $Repo 'agents') -Filter '*.md' -File | Where-Object { $_.Name -ne 'README.md' } | ForEach-Object {
    $agent = $_.FullName
    $name = $_.Name
    foreach ($d in $AgentDirs) { Install-Link -Src $agent -Dst (Join-Path $d $name) }
}

# --- shared references --------------------------------------------------------
Write-Host ''
Write-Host "references ->  $($RefDirs -join ', ')"
foreach ($d in $RefDirs) { Install-Link -Src (Join-Path $Repo 'references') -Dst $d }

# --- done ---------------------------------------------------------------------
Write-Host ''
if ($DryRun) {
    Write-Host 'dry run complete -- re-run without -DryRun to apply' -ForegroundColor DarkGray
} else {
    Write-Host "done. Skills update on 'git pull' -- no reinstall needed." -ForegroundColor Green
    if ($script:BackedUp) { Write-Host "Replaced files were moved to: $Backup" -ForegroundColor Yellow }
}
if ($script:UsedHardLink) {
    Write-Host ''
    Write-Host 'Note: agent files were linked with hardlinks (no permission for real symlinks' -ForegroundColor Yellow
    Write-Host 'here). A hardlink breaks if something replaces the file instead of editing it' -ForegroundColor Yellow
    Write-Host 'in place (sed -i, some editor atomic-saves, occasionally git checkout). If an' -ForegroundColor Yellow
    Write-Host 'agent stops updating on git pull, re-run this script. For real symlinks, enable' -ForegroundColor Yellow
    Write-Host 'Developer Mode (Settings > Privacy & security > For developers) and run this' -ForegroundColor Yellow
    Write-Host 'from a normal (non-sandboxed) terminal, or run once as Administrator.' -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'Hooks are NOT installed by this script -- they need settings.json entries.'
Write-Host 'See hooks\README.md and add them yourself.'
