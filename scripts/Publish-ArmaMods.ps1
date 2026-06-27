#Requires -Version 5.1
<#
.SYNOPSIS
    Builds and publishes Gruppe 9 Arma mods into an Arma server mods directory.

.DESCRIPTION
    Creates real @mod folders from HEMTT build outputs:
    - @grp9_stats
    - @grp9_stats_server
    - @grp9_mod, when the separate Gruppe 9 Mod repository is present

    The server mod config file is intentionally not overwritten if it already
    exists, because it contains the production machine token.
#>

[CmdletBinding()]
param(
    [string]$ArmaModsRoot = "",
    [string]$Gruppe9ModRoot = "F:\#Communitys\Arma Server\Gruppe 9 Mod",
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ArmaModsRoot)) {
    $ArmaModsRoot = Join-Path $RepoRoot "mods"
}

function New-ModCpp {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Tooltip,
        [Parameter(Mandatory = $true)][string]$Overview
    )

    @"
name = "$Name";
author = "Gruppe 9";
tooltip = "$Tooltip";
overview = "$Overview";
hideName = 0;
hidePicture = 0;
"@ | Set-Content -LiteralPath $Path -Encoding ASCII
}

function Sync-Addons {
    param(
        [Parameter(Mandatory = $true)][string]$SourceAddons,
        [Parameter(Mandatory = $true)][string]$TargetModRoot
    )

    if (!(Test-Path -LiteralPath $SourceAddons)) {
        throw "Source addons folder not found: $SourceAddons"
    }

    $targetAddons = Join-Path $TargetModRoot "addons"
    if (Test-Path -LiteralPath $targetAddons) {
        Remove-Item -LiteralPath $targetAddons -Recurse -Force
    }

    New-Item -ItemType Directory -Path $targetAddons -Force | Out-Null
    Copy-Item -Path (Join-Path $SourceAddons "*") -Destination $targetAddons -Recurse -Force
}

function Publish-ClientMod {
    param(
        [Parameter(Mandatory = $true)][string]$SourceAddons,
        [Parameter(Mandatory = $true)][string]$TargetName,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][string]$Tooltip,
        [Parameter(Mandatory = $true)][string]$Overview
    )

    $targetRoot = Join-Path $ArmaModsRoot $TargetName
    New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    Sync-Addons -SourceAddons $SourceAddons -TargetModRoot $targetRoot
    New-ModCpp -Path (Join-Path $targetRoot "mod.cpp") -Name $DisplayName -Tooltip $Tooltip -Overview $Overview
    Write-Host "Published $TargetName -> $targetRoot"
}

if (!$SkipBuild) {
    Write-Host "Building @grp9_stats..."
    Push-Location (Join-Path $RepoRoot "addons\grp9_stats")
    try {
        hemtt build
    } finally {
        Pop-Location
    }

    Write-Host "Building @grp9_stats_server..."
    & (Join-Path $RepoRoot "scripts\Build-ServerModPackage.ps1")

    if (Test-Path -LiteralPath $Gruppe9ModRoot) {
        Write-Host "Building @grp9_mod..."
        Push-Location $Gruppe9ModRoot
        try {
            hemtt build
        } finally {
            Pop-Location
        }
    } else {
        Write-Warning "Gruppe 9 Mod repository not found: $Gruppe9ModRoot"
    }
}

New-Item -ItemType Directory -Path $ArmaModsRoot -Force | Out-Null

Publish-ClientMod `
    -SourceAddons (Join-Path $RepoRoot "addons\grp9_stats\.hemttout\build\addons") `
    -TargetName "@grp9_stats" `
    -DisplayName "Gruppe 9 Stats" `
    -Tooltip "Gruppe 9 Stats Tracking" `
    -Overview "Client-safe Gruppe 9 stats tracking addon."

$serverSourceRoot = Join-Path $RepoRoot "servermod\grp9_stats_server\.hemttout\build"
$serverTargetRoot = Join-Path $ArmaModsRoot "@grp9_stats_server"
New-Item -ItemType Directory -Path $serverTargetRoot -Force | Out-Null
Sync-Addons -SourceAddons (Join-Path $serverSourceRoot "addons") -TargetModRoot $serverTargetRoot
New-ModCpp `
    -Path (Join-Path $serverTargetRoot "mod.cpp") `
    -Name "Gruppe 9 Stats Server" `
    -Tooltip "Gruppe 9 Stats Server Integration" `
    -Overview "Server-only Gruppe 9 stats tracking extension and API bridge."

Copy-Item -LiteralPath (Join-Path $serverSourceRoot "grp9_stats_ext_x64.dll") -Destination (Join-Path $serverTargetRoot "grp9_stats_ext_x64.dll") -Force
New-Item -ItemType Directory -Path (Join-Path $serverTargetRoot "storage") -Force | Out-Null

$serverConfig = Join-Path $serverTargetRoot "grp9_stats_server.toml"
if (!(Test-Path -LiteralPath $serverConfig)) {
    Copy-Item -LiteralPath (Join-Path $RepoRoot "servermod\grp9_stats_server\grp9_stats_server.example.toml") -Destination $serverConfig -Force
    Write-Warning "Created example server config. Set the real machine_token in: $serverConfig"
} else {
    Write-Host "Keeping existing server config: $serverConfig"
}
Write-Host "Published @grp9_stats_server -> $serverTargetRoot"

if (Test-Path -LiteralPath $Gruppe9ModRoot) {
    Publish-ClientMod `
        -SourceAddons (Join-Path $Gruppe9ModRoot ".hemttout\build\addons") `
        -TargetName "@grp9_mod" `
        -DisplayName "Gruppe 9 Mod" `
        -Tooltip "Gruppe 9 Arma Mod" `
        -Overview "Gruppe 9 main menu and Eden/Zeus utility modules."
}

Write-Host ""
Write-Host "Use these startup parameters:"
Write-Host "  -mod=@CBA_A3;@grp9_mod;@grp9_stats"
Write-Host "  -serverMod=@grp9_stats_server"
