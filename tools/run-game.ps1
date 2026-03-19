param(
	[switch]$UseGlobal,
	[switch]$Headless,
	[switch]$Quit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve-godot.ps1")

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$preferConsole = $Headless -or $Quit
$exe = Get-GodotExecutable -PreferPortable:(-not $UseGlobal) -PreferConsole:$preferConsole
$arguments = @("--path", $projectRoot)

if ($Headless) {
	$arguments += "--headless"
}

if ($Quit) {
	$arguments += "--quit"
}

& $exe @arguments
