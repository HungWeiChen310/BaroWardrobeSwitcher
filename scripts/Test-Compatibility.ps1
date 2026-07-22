param(
    [Parameter(Mandatory = $true)]
    [string] $BarotraumaInstallDir,

    [Parameter(Mandatory = $true)]
    [string] $LuaCsPublicizedDir,

    [switch] $RequireOptional
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "tools/CompatibilityProbe/CompatibilityProbe.csproj"

$arguments = @($BarotraumaInstallDir, $LuaCsPublicizedDir)
if ($RequireOptional) { $arguments += "--require-optional" }

& dotnet run --project $project -c Release -- @arguments
exit $LASTEXITCODE
