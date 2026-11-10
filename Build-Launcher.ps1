$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'The .NET Framework C# compiler is unavailable.' }
$automation = [Reflection.Assembly]::Load('System.Management.Automation').Location
$source = Join-Path $PSScriptRoot 'Launcher.cs'
$output = Join-Path $PSScriptRoot 'ChatGPTAccountSwitcher.exe'
& $compiler /nologo /target:winexe /platform:x64 /out:$output /reference:$automation /reference:System.Windows.Forms.dll $source
if ($LASTEXITCODE -ne 0) { throw 'Launcher compilation failed.' }
$glassSource = Join-Path $PSScriptRoot 'LiquidGlass.Controls.cs'
$glassOutput = Join-Path $PSScriptRoot 'LiquidGlass.Controls.dll'
& $compiler /nologo /target:library /platform:x64 /out:$glassOutput /reference:System.Drawing.dll /reference:System.Windows.Forms.dll $glassSource
if ($LASTEXITCODE -ne 0) { throw 'Glass controls compilation failed.' }
Write-Output $output
