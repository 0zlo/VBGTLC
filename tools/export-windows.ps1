param(
	[string]$OutputPath = "build/windows/template.exe",
	[switch]$UseGlobal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve-godot.ps1")

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$exe = Get-GodotExecutable -PreferPortable:(-not $UseGlobal) -PreferConsole

if ([System.IO.Path]::IsPathRooted($OutputPath)) {
	$resolvedOutputPath = $OutputPath
} else {
	$resolvedOutputPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $OutputPath))
}

New-Item -Path (Split-Path -Path $resolvedOutputPath -Parent) -ItemType Directory -Force | Out-Null

& $exe --headless --path $projectRoot --export-release "Windows Desktop" $resolvedOutputPath

if ($LASTEXITCODE -ne 0 -or -not (Test-Path -Path $resolvedOutputPath -PathType Leaf)) {
	throw "Export failed. Install templates with tools/install-export-templates.ps1 (or via Editor > Manage Export Templates), then retry."
}

Write-Host "Exported Windows build to: $resolvedOutputPath"
