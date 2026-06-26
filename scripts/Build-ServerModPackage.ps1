#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the @grp9_stats_server package for local Windows x64 testing.

.DESCRIPTION
    Runs the HEMTT serverMod build, builds the native Rust extension in release
    mode, and copies the extension DLL into the HEMTT build output using the
    Arma 3 x64 extension naming convention.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ServerModRoot = Join-Path $RepoRoot "servermod\grp9_stats_server"
$ExtensionRoot = Join-Path $RepoRoot "extension\grp9_stats_ext"
$OutputRoot = Join-Path $ServerModRoot ".hemttout\build"
$ExtensionDll = Join-Path $ExtensionRoot "target\release\grp9_stats_ext.dll"
$OutputDll = Join-Path $OutputRoot "grp9_stats_ext_x64.dll"
$ExampleConfig = Join-Path $ServerModRoot "grp9_stats_server.example.toml"
$OutputConfig = Join-Path $OutputRoot "grp9_stats_server.example.toml"
$StorageDir = Join-Path $OutputRoot "storage"

Write-Host "Building @grp9_stats_server PBO with HEMTT..."
Push-Location $ServerModRoot
try {
    hemtt build
} finally {
    Pop-Location
}

Write-Host "Building grp9_stats_ext release DLL with Cargo..."
Push-Location $ExtensionRoot
try {
    cargo build --release
} finally {
    Pop-Location
}

if (!(Test-Path -LiteralPath $ExtensionDll)) {
    throw "Expected extension DLL not found: $ExtensionDll"
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
New-Item -ItemType Directory -Path $StorageDir -Force | Out-Null
Copy-Item -LiteralPath $ExtensionDll -Destination $OutputDll -Force
Copy-Item -LiteralPath $ExampleConfig -Destination $OutputConfig -Force

Write-Host "ServerMod package ready:"
Write-Host "  $OutputRoot"
Write-Host ""
Write-Host "Before deployment, copy grp9_stats_server.example.toml to grp9_stats_server.toml and set the real machine token."
