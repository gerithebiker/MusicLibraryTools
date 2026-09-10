<#
.SYNOPSIS
    Creates a plan for record-label catalogue pointers based on music album
    directory names.

.DESCRIPTION
    Write-RecordLabelPointers.ps1 scans the configured music library and
    identifies album directories using the following naming convention:

        YYYY - Album Title (ReissueYear Label1, Label2 Resolution)

    Examples:

        1962 - Standard Coltrane (2002 Analogue Productions DSD64)
        1959 - Kind of Blue (Columbia 24-192)
        1977 - Heavy Weather (CBS, Columbia 16-44)
        1965 - Album Title

    Only the metadata inside the final parentheses is processed.

    The script attempts to identify:

        - Optional reissue year at the beginning of the metadata
        - Zero, one, or multiple record labels
        - Optional audio resolution at the end of the metadata

    Multiple record labels must be separated by commas.

    For each recognized label, the script creates a planned catalogue entry
    using the following format:

        /music/Label Catalogue/<Label>/<OriginalYear> - <Album Title> (<Resolution>)

    Example source directory:

        /music/John Coltrane {jazz, tenor sax}/
        1962 - Standard Coltrane (2002 Analogue Productions DSD64)

    Planned pointer:

        /music/Label Catalogue/Analogue Productions/
        1962 - Standard Coltrane (DSD64)

    The reissue year and record-label information are omitted from the pointer
    name. The resolution is retained when present.

    If no resolution is present, no parentheses or additional trailing space
    are added.

    The current version only creates and validates a pointer plan. It does not
    create symbolic links.

    Configuration values, patterns, exclusions, and label aliases are read
    from the shared mTools.ini configuration file.

.PARAMETER ConfigPath
    Path to the mTools.ini configuration file.

    Default:

        <script directory>\mTools.ini

.INPUTS
    None.

    The script scans directories specified in mTools.ini.

.OUTPUTS
    CSV plan containing the proposed symbolic links.

    A separate warnings CSV may also be created for directories that cannot
    be parsed or would produce conflicting pointer paths.

.EXAMPLE
    .\Write-RecordLabelPointers.ps1

    Uses mTools.ini from the script directory.

.EXAMPLE
    .\Write-RecordLabelPointers.ps1 `
        -ConfigPath "C:\MusicLibraryTools\mTools.ini"

    Uses the specified configuration file.

.NOTES
    Script:  Write-RecordLabelPointers.ps1
    Project: Music Library Tools

    Supported resolution values:

        192
        320
        16-44
        24-44
        24-88
        24-96
        24-176
        24-192
        24-352
        DSD64
        DSD128
        DSD256
        DSD512
        DSD1024

    Album directories without record-label information are skipped.

    Label aliases and all configurable parsing rules must remain outside the
    script and be stored in mTools.ini.

.LINK
    Get-Help

.LINK
    about_Comment_Based_Help
#>

[CmdletBinding()]
param (
    [string]$ConfigPath = "$PSScriptRoot\mTools.ini"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Remove-IniQuotes {
    param (
        [AllowEmptyString()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if (
        $Value.Length -ge 2 -and
        $Value.StartsWith('"') -and
        $Value.EndsWith('"')
    ) {
        return $Value.Substring(1, $Value.Length - 2)
    }

    return $Value
}


function Read-IniFile {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "INI file not found: $Path"
    }

    $result = [ordered]@{}
    $currentSection = $null

    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()

        if (
            [string]::IsNullOrWhiteSpace($line) -or
            $line.StartsWith('#') -or
            $line.StartsWith(';')
        ) {
            continue
        }

        if ($line -match '^\[(?<Section>[^\]]+)\]$') {
            $currentSection = $Matches.Section

            if (-not $result.Contains($currentSection)) {
                $result[$currentSection] = [ordered]@{}
            }

            continue
        }

        if ($null -eq $currentSection) {
            throw "INI value found outside a section: $rawLine"
        }

        if ($rawLine -match '^\s*(?<Key>[^=]+?)\s*=\s*(?<Value>.*)$') {
            $key = $Matches.Key.Trim()
            $value = Remove-IniQuotes -Value $Matches.Value.Trim()

            $result[$currentSection][$key] = $value
        }
    }

    return $result
}


#---------------------------------------------------------[Helper Functions]---------------------------------------------------------

function Get-NormalizedLabel {
    param (
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Aliases
    )

    $labelName = $Label.Trim()

    foreach ($aliasName in $Aliases.Keys) {
        if ($labelName -ieq $aliasName) {
            return [string]$Aliases[$aliasName]
        }
    }

    return $labelName
}


function Convert-ToNasPath {
    param (
        [Parameter(Mandatory)]
        [string]$WindowsPath,

        [Parameter(Mandatory)]
        [string]$WindowsRoot,

        [Parameter(Mandatory)]
        [string]$NasRoot
    )

    $normalizedWindowsRoot = $WindowsRoot.TrimEnd('\')
    $relativePath = $WindowsPath.Substring($normalizedWindowsRoot.Length)
    $relativePath = $relativePath.TrimStart('\')

    if ([string]::IsNullOrWhiteSpace($relativePath)) {
        return $NasRoot.TrimEnd('/')
    }

    return (
        $NasRoot.TrimEnd('/') + '/' +
        ($relativePath -replace '\\', '/')
    )
}


#--------------------------------------------------------------[Main]---------------------------------------------------------------

$config = Read-IniFile -Path $ConfigPath

$settings = $config['recordLabelPointers']
$patterns = $config['recordLabelPatterns']
$labelAliases = $config['labelAliases']

$sourceRoot = $settings['sourceRoot']
$nasRoot = $settings['nasRoot']
$catalogueFolder = $settings['catalogueFolder']
$planFile = $settings['planFile']

$excludedDirectories = @(
    $settings['excludeDirs'] -split '\|' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
)

$albumFolderPattern = $patterns['albumFolder']
$reissueYearPattern = $patterns['reissueYear']
$resolutionPattern = $patterns['resolution']

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Music root not found: $sourceRoot"
}

$plan = [System.Collections.Generic.List[object]]::new()
$warnings = [System.Collections.Generic.List[object]]::new()


$artistDirectories = Get-ChildItem `
    -LiteralPath $sourceRoot `
    -Directory `
    -Force |
    Where-Object {
        $_.Name -notin $excludedDirectories
    }


foreach ($artistDirectory in $artistDirectories) {

    $albumDirectories = Get-ChildItem `
        -LiteralPath $artistDirectory.FullName `
        -Directory `
        -Force

    foreach ($albumDirectory in $albumDirectories) {

        if ($albumDirectory.Name -notmatch $albumFolderPattern) {
            $warnings.Add([pscustomobject]@{
                AlbumPath = $albumDirectory.FullName
                Reason    = 'Album folder name does not match the configured format.'
            })

            continue
        }

        $albumYear = $Matches.Year
        $albumTitle = $Matches.Title.Trim()
        $metadata = $Matches.Metadata

        if ([string]::IsNullOrWhiteSpace($metadata)) {
            continue
        }

        $metadata = $metadata.Trim()
        $resolution = $null
        $reissueYear = $null


        # Resolution is always expected at the end.
        if ($metadata -match $resolutionPattern) {
            $resolution = $Matches.Resolution

            $metadata = $metadata.Substring(
                0,
                $Matches.Index
            ).Trim()
        }


        # Reissue year is expected at the beginning.
        if ($metadata -match $reissueYearPattern) {
            $reissueYear = $Matches.ReissueYear

            $metadata = $metadata.Substring(
                $Matches.Length
            ).Trim()
        }


        # Whatever remains is the comma-separated label list.
        if ([string]::IsNullOrWhiteSpace($metadata)) {
            continue
        }

        $labels = @(
            $metadata -split ',' |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ }
        )

        if ($labels.Count -eq 0) {
            continue
        }


        if ($resolution) {
            $linkName = '{0} - {1} ({2})' -f `
                $albumYear,
                $albumTitle,
                $resolution
        }
        else {
            $linkName = '{0} - {1}' -f `
                $albumYear,
                $albumTitle
        }


        $targetNasPath = Convert-ToNasPath `
            -WindowsPath $albumDirectory.FullName `
            -WindowsRoot $sourceRoot `
            -NasRoot $nasRoot


        foreach ($rawLabel in $labels) {
            $label = Get-NormalizedLabel `
                -Label $rawLabel `
                -Aliases $labelAliases

            $linkNasPath = '{0}/{1}/{2}/{3}' -f `
                $nasRoot.TrimEnd('/'),
                $catalogueFolder.Trim('/'),
                $label,
                $linkName

            $plan.Add([pscustomobject]@{
                Label          = $label
                OriginalLabel  = $rawLabel
                AlbumYear      = $albumYear
                ReissueYear    = $reissueYear
                Resolution     = $resolution
                LinkName       = $linkName
                LinkPath       = $linkNasPath
                TargetPath     = $targetNasPath
                SourceFolder   = $albumDirectory.FullName
            })
        }
    }
}


# Duplicate link path detection.
$duplicateLinkPaths = @(
    $plan |
        Group-Object -Property LinkPath |
        Where-Object Count -gt 1
)

foreach ($duplicate in $duplicateLinkPaths) {
    foreach ($item in $duplicate.Group) {
        $warnings.Add([pscustomobject]@{
            AlbumPath = $item.SourceFolder
            Reason    = "Duplicate link path: $($item.LinkPath)"
        })
    }
}


$plan |
    Sort-Object Label, LinkName |
    Export-Csv `
        -LiteralPath $planFile `
        -NoTypeInformation `
        -Encoding UTF8


Write-Host
Write-Host "Albums scanned : $(
    ($artistDirectories |
        ForEach-Object {
            Get-ChildItem -LiteralPath $_.FullName -Directory -Force
        }).Count
)" -ForegroundColor Cyan

Write-Host "Links planned  : $($plan.Count)" -ForegroundColor Green
Write-Host "Warnings       : $($warnings.Count)" -ForegroundColor Yellow
Write-Host "Plan file      : $planFile" -ForegroundColor Cyan


if ($warnings.Count -gt 0) {
    $warningFile = [System.IO.Path]::ChangeExtension(
        $planFile,
        '.warnings.csv'
    )

    $warnings |
        Export-Csv `
            -LiteralPath $warningFile `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Host "Warning file   : $warningFile" -ForegroundColor Yellow
}