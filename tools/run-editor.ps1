param(
	[switch]$UseGlobal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve-godot.ps1")

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$exe = Get-GodotExecutable -PreferPortable:(-not $UseGlobal)

& $exe --path $projectRoot --editor
