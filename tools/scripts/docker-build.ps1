<#
 .SYNOPSIS
    Build docker container for a container.json definition in the tree.

 .PARAMETER Path
    The folder to build the docker files from which also contains
    the container.json file.

 .PARAMETER ImageName
    The name of the image.

 .PARAMETER Debug
    Build debug and include debugger into images (where applicable)
#>

Param(
    [string] $Path = ".",
    [string] $ImageName,
    [switch] $Debug
)

if ([string]::IsNullOrEmpty($ImageName)) {
    throw "Must specify an image name"
}

Write-Host "Building $($ImageName)"

# Source definitions
$definitions = & (Join-Path $PSScriptRoot "docker-source.ps1") `
    -Path $Path -Debug:$Debug
if ($definitions.Count -eq 0) {
    Write-Host "Nothing to build."
    return
}

# Get currently active platform
$dockerversion = &docker @("version") 2>&1 | %{ "$_" } `
    | ConvertFrom-Csv -Delimiter ':' -Header @("Key", "Value") `
    | Where-Object { $_.Key -eq "OS/Arch" } `
    | ForEach-Object { $platform = $_.Value }
if ($LastExitCode -ne 0) {
    throw "docker version failed with $($LastExitCode)."
}

if ([string]::IsNullOrEmpty($platform)) {
    $platform = "linux/amd64"
}
if ($platform -eq "windows/amd64") {
    $osVerToPlatform = @{
        "10.0.17134" = "windows/amd64:10.0.17134.885"
        "10.0.17763" = "windows/amd64:10.0.17763.615"
        "10.0.18362" = "windows/amd64:10.0.17134.885"
    }
    $osver = (Get-WmiObject Win32_OperatingSystem).Version
    $platform = $osVerToPlatform.Item($osver)
}
Write-Host "Current docker OS/Arch: $platform"

# Select build definition
$def = $definitions `
    | Where-Object { $_.platform -eq $platform } `
    | Select-Object

# Build docker image from definition
$dockerfile = $def.dockerfile
$buildContext = $def.buildContext

# Create docker build command line
$argumentList = @("build",
    "-f", $dockerfile,
    "-t", "$($ImageName):latest"
)
$argumentList += $buildContext
& docker $argumentList 2>&1 | %{ "$_" }
if ($LastExitCode -ne 0) {
    throw "Error building $($ImageName): 'docker $($args)' failed with $($LastExitCode)."
}
