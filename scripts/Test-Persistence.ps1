param(
    [Parameter(Mandatory = $true)]
    [string] $BarotraumaInstallDir,

    [Parameter(Mandatory = $true)]
    [string] $LuaCsPublicizedDir
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot "Build.ps1") `
    -BarotraumaInstallDir $BarotraumaInstallDir `
    -LuaCsPublicizedDir $LuaCsPublicizedDir `
    -Configuration Release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$project = Join-Path $root "tools/PersistenceProbe/PersistenceProbe.csproj"
$assembly = Join-Path $root "artifacts/bin/Release/BaroWardrobeSwitcher.dll"
& dotnet run --project $project -c Release -- $assembly $BarotraumaInstallDir $LuaCsPublicizedDir
exit $LASTEXITCODE
