param(
	[switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$portableDir = Join-Path $projectRoot ".godot-portable"
$portableEditor = Join-Path $portableDir "godot.exe"
$portableConsole = Join-Path $portableDir "godot_console.exe"
$selfContainedMarker = Join-Path $portableDir "_sc_"

$godotCmd = Get-Command godot -ErrorAction Stop
$godotConsoleCmd = Get-Command godot_console -ErrorAction SilentlyContinue

New-Item -Path $portableDir -ItemType Directory -Force | Out-Null

if ($Force -or -not (Test-Path -Path $portableEditor -PathType Leaf)) {
	Copy-Item -Path $godotCmd.Source -Destination $portableEditor -Force
}

if ($null -ne $godotConsoleCmd -and ($Force -or -not (Test-Path -Path $portableConsole -PathType Leaf))) {
	Copy-Item -Path $godotConsoleCmd.Source -Destination $portableConsole -Force
}

if (-not (Test-Path -Path $selfContainedMarker -PathType Leaf)) {
	New-Item -Path $selfContainedMarker -ItemType File | Out-Null
}

$versionExe = $portableConsole
if (-not (Test-Path -Path $versionExe -PathType Leaf)) {
	$versionExe = $portableEditor
}

$version = (& $versionExe --version) -join ""
Write-Host "Portable Godot prepared at $portableEditor"
Write-Host "Version: $version"
Write-Host "Self-contained mode: enabled ($selfContainedMarker)"
