param(
  [Parameter(Mandatory = $true)][string]$BuildDir,
  [Parameter(Mandatory = $true)][string]$AssetDir,
  [Parameter(Mandatory = $true)][ValidateSet("x64", "arm64")][string]$Arch,
  [string]$Version = "8",
  [Parameter(Mandatory = $true)][string]$BindiffJar,
  [string]$GhidraBinExportZip = ""
)

$ErrorActionPreference = "Stop"

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ("bindiff-release-" + [guid]::NewGuid().ToString("N"))
$SourceDir = Join-Path $WorkDir "SourceDir"
$AppDir = Join-Path $SourceDir "ProgramFiles\BinDiff"
$WixObjDir = Join-Path $WorkDir "wixobj"
$WixRoot = if ($env:WIX) { $env:WIX } elseif (Test-Path "${env:ProgramFiles(x86)}\WiX Toolset v3.14\bin") { "${env:ProgramFiles(x86)}\WiX Toolset v3.14\bin" } else { throw "WiX Toolset v3.14 not found" }
$Heat = Join-Path $WixRoot "heat.exe"
$Candle = Join-Path $WixRoot "candle.exe"
$Light = Join-Path $WixRoot "light.exe"

New-Item -ItemType Directory -Force -Path $SourceDir, $AppDir, $WixObjDir, $AssetDir | Out-Null
Copy-Item (Join-Path $RootDir "packaging\msi\SourceDir\*") $SourceDir -Recurse -Force

$Outputs = python (Join-Path $RootDir "scripts\release\find_build_outputs.py") $BuildDir | ConvertFrom-Json
if (-not $Outputs.bindiff -or -not $Outputs.bindiff_config_setup -or -not $Outputs.binexport2dump) {
  throw "Missing required build outputs for Windows packaging"
}

New-Item -ItemType Directory -Force -Path `
  (Join-Path $AppDir "bin"), `
  (Join-Path $AppDir "Extra\Config"), `
  (Join-Path $AppDir "Extra\Ghidra"), `
  (Join-Path $AppDir "Plugins\IDA Pro") | Out-Null

Copy-Item $Outputs.bindiff (Join-Path $AppDir "bin\bindiff.exe") -Force
Copy-Item $Outputs.bindiff_config_setup (Join-Path $AppDir "bin\bindiff_config_setup.exe") -Force
Copy-Item $Outputs.binexport2dump (Join-Path $AppDir "bin\binexport2dump.exe") -Force
Copy-Item $BindiffJar (Join-Path $AppDir "bin\bindiff.jar") -Force
Copy-Item (Join-Path $RootDir "bindiff_config.proto") (Join-Path $AppDir "Extra\Config\bindiff_config.proto") -Force
Copy-Item (Join-Path $RootDir "bindiff.json") (Join-Path $SourceDir "CommonAppData\BinDiff\bindiff.json") -Force

if ($GhidraBinExportZip -and (Test-Path $GhidraBinExportZip)) {
  Expand-Archive -Path $GhidraBinExportZip -DestinationPath (Join-Path $AppDir "Extra\Ghidra") -Force
} elseif (-not (Test-Path (Join-Path $AppDir "Extra\Ghidra\Read Me.txt"))) {
  Set-Content -Path (Join-Path $AppDir "Extra\Ghidra\Read Me.txt") -Value "Optional Ghidra extension artifact not bundled in this build."
}

foreach ($PluginPath in @($Outputs.bindiff_ida, $Outputs.bindiff_ida64, $Outputs.binexport_ida, $Outputs.binexport_ida64)) {
  if ($PluginPath -and (Test-Path $PluginPath)) {
    Copy-Item $PluginPath (Join-Path $AppDir "Plugins\IDA Pro") -Force
  }
}

$crtArch = if ($Arch -eq "x64") { "x64" } else { "arm64" }
if ($env:VCToolsRedistDir) {
  $crtDir = Join-Path $env:VCToolsRedistDir "$crtArch\Microsoft.VC143.CRT"
  if (Test-Path $crtDir) {
    Copy-Item (Join-Path $crtDir "*.dll") (Join-Path $AppDir "bin") -Force
  }
}

& (Join-Path $env:JAVA_HOME "bin\jlink.exe") `
  --module-path (Join-Path $env:JAVA_HOME "jmods") `
  --no-header-files `
  --compress=2 `
  --strip-debug `
  --add-modules java.base,java.desktop,java.prefs,java.scripting,java.sql,jdk.unsupported,jdk.xml.dom `
  --output (Join-Path $AppDir "jre")

& $Heat dir $AppDir `
  -nologo -gg -sfrag -srd -dr INSTALLDIR -cg BinDiffAppFiles `
  -out (Join-Path $WorkDir "AppFiles.wxs")

$wixDefines = @(
  "-dProjectDir=$($RootDir)\scripts\release\",
  "-dVersion=$Version.0.0",
  "-dPlatform=$Arch"
)

& $Candle -nologo @wixDefines `
  -ext WixUtilExtension `
  -ext WixUIExtension `
  -out "$WixObjDir\" `
  (Join-Path $WorkDir "AppFiles.wxs") `
  (Join-Path $RootDir "scripts\release\windows-installer.wxs")

& $Light -nologo `
  -ext WixUtilExtension `
  -ext WixUIExtension `
  -cultures:en-us `
  -o (Join-Path $AssetDir "bindiff${Version}-windows-${Arch}.msi") `
  (Join-Path $WixObjDir "AppFiles.wixobj") `
  (Join-Path $WixObjDir "windows-installer.wixobj")
