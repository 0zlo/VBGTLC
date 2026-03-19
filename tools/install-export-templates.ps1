param(
	[switch]$UseGlobal,
	[switch]$Force,
	[string]$TemplateArchivePath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve-godot.ps1")

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$exe = Get-GodotExecutable -PreferPortable:(-not $UseGlobal) -PreferConsole
$versionRaw = (& $exe --version | Select-Object -First 1).Trim()

if ($versionRaw -notmatch "^(?<base>\d+\.\d+\.\d+)\.(?<channel>[a-z0-9]+)") {
	throw "Unable to parse Godot version from '$versionRaw'."
}

$baseVersion = $Matches.base
$channel = $Matches.channel
$templateVersion = "$baseVersion.$channel"
$releaseTag = "$baseVersion-$channel"

if ($UseGlobal) {
	$templatesRoot = Join-Path ([Environment]::GetFolderPath("ApplicationData")) "Godot\export_templates"
} else {
$templatesRoot = Join-Path $projectRoot ".godot-portable\editor_data\export_templates"
}

$targetDir = Join-Path $templatesRoot $templateVersion
$debugTemplate = Join-Path $targetDir "windows_debug_x86_64.exe"
$releaseTemplate = Join-Path $targetDir "windows_release_x86_64.exe"

if (-not $Force -and (Test-Path -Path $debugTemplate -PathType Leaf) -and (Test-Path -Path $releaseTemplate -PathType Leaf)) {
	Write-Host "Export templates already installed in $targetDir"
	return
}

$downloadUrl = "https://github.com/godotengine/godot/releases/download/$releaseTag/Godot_v${releaseTag}_export_templates.tpz"
$tempRoot = Join-Path $env:TEMP ("godot-templates-" + [Guid]::NewGuid().ToString("N"))
$tpzPath = Join-Path $tempRoot "templates.tpz"
$zipPath = Join-Path $tempRoot "templates.zip"
$extractDir = Join-Path $tempRoot "extract"

try {
	New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

	if ([string]::IsNullOrWhiteSpace($TemplateArchivePath)) {
		Invoke-WebRequest -Uri $downloadUrl -OutFile $tpzPath
	} else {
		$resolvedArchive = [System.IO.Path]::GetFullPath($TemplateArchivePath)
		if (-not (Test-Path -Path $resolvedArchive -PathType Leaf)) {
			throw "Template archive not found: $resolvedArchive"
		}
		Copy-Item -Path $resolvedArchive -Destination $tpzPath -Force
	}

	Copy-Item -Path $tpzPath -Destination $zipPath -Force
	Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

	$templateSource = Join-Path $extractDir "templates"
	if (-not (Test-Path -Path $templateSource -PathType Container)) {
		$candidate = Get-ChildItem -Path $extractDir -Directory | Where-Object {
			Test-Path -Path (Join-Path $_.FullName "windows_release_x86_64.exe") -PathType Leaf
		} | Select-Object -First 1
		if ($null -ne $candidate) {
			$templateSource = $candidate.FullName
		}
	}

	New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
	Copy-Item -Path (Join-Path $templateSource "*") -Destination $targetDir -Recurse -Force

	if (-not (Test-Path -Path $debugTemplate -PathType Leaf) -or -not (Test-Path -Path $releaseTemplate -PathType Leaf)) {
		throw "Templates copied but expected Windows template binaries were not found in $targetDir"
	}

	Write-Host "Installed Godot export templates $templateVersion into $targetDir"
}
finally {
	if (Test-Path -Path $tempRoot -PathType Container) {
		Remove-Item -Path $tempRoot -Recurse -Force
	}
}
