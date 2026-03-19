Set-StrictMode -Version Latest

function Get-GodotExecutable {
	param(
		[switch]$PreferPortable,
		[switch]$PreferConsole
	)

	$portableFileName = "godot.exe"
	$fallbackPortableFileName = "godot_console.exe"
	$commandName = "godot"
	$fallbackCommandName = "godot_console"
	if ($PreferConsole) {
		$portableFileName = "godot_console.exe"
		$fallbackPortableFileName = "godot.exe"
		$commandName = "godot_console"
		$fallbackCommandName = "godot"
	}

	$portableExe = Join-Path $PSScriptRoot "..\.godot-portable\$portableFileName"
	$portableExe = [System.IO.Path]::GetFullPath($portableExe)
	if ($PreferPortable -and (Test-Path -Path $portableExe -PathType Leaf)) {
		return $portableExe
	}

	$fallbackPortableExe = Join-Path $PSScriptRoot "..\.godot-portable\$fallbackPortableFileName"
	$fallbackPortableExe = [System.IO.Path]::GetFullPath($fallbackPortableExe)
	if ($PreferPortable -and (Test-Path -Path $fallbackPortableExe -PathType Leaf)) {
		return $fallbackPortableExe
	}

	$godotCommand = Get-Command $commandName -ErrorAction SilentlyContinue
	if ($null -ne $godotCommand) {
		return $godotCommand.Source
	}

	$fallbackGodotCommand = Get-Command $fallbackCommandName -ErrorAction SilentlyContinue
	if ($null -ne $fallbackGodotCommand) {
		return $fallbackGodotCommand.Source
	}

	throw "Godot executable not found. Install Godot 4 or run tools/bootstrap-portable-godot.ps1 after installing."
}
