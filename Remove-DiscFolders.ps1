<#
.SYNOPSIS
    Removes Disc/CD/Disk subfolders from an album folder.

.DESCRIPTION
    Run this script from the album directory, or pass -AlbumPath.

    It detects disc folders such as:
        Disc 1
        Disc 2
        CD 1
        Disk 01

    Audio files are moved up and renamed with disc-aware track prefixes:
        Disc 1\01 - Song.flac  -> 101 - Song.flac
        Disc 2\01 - Song.flac  -> 201 - Song.flac
        Disc 10\01 - Song.flac -> 1001 - Song.flac

    If the album has 10 or more discs, disc numbers are padded:
        Disc 1\01 - Song.flac  -> 0101 - Song.flac
        Disc 10\01 - Song.flac -> 1001 - Song.flac

    Image files are moved up and renamed with the disc prefix:
        Disc 1\folder.jpg -> folder1.jpg
        Disc 2\folder.jpg -> folder2.jpg

    Document files are moved up and renamed with the disc folder name:
        Disc 1\booklet.pdf -> Disc 1-booklet.pdf
        Disc 2\booklet.pdf -> Disc 2-booklet.pdf

    info.txt is treated as a special useful text file:
        Disc 1\info.txt -> Disc 1-info.txt

.PARAMETER Execute
    Actually performs the move/delete operations.
    Without this switch, the script only prints what it would do.

.PARAMETER AlbumPath
    Album folder path. If omitted, current directory is used.

.EXAMPLE
    .\Remove-DiscFolders.ps1

.EXAMPLE
    .\Remove-DiscFolders.ps1 -Execute

.EXAMPLE
    .\Remove-DiscFolders.ps1 -Execute -AlbumPath "C:\Music\Album"

.NOTES
    Designed for music library cleanup.
    Conservative default: dry-run unless -Execute is specified.
#>

param(
    [switch]$Execute,
    [string]$AlbumPath
)

# ---------- Configuration ----------

$DiscFolderNames = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@(
        'disc',
        'disk',
        'cd'
    ),
    [System.StringComparer]::OrdinalIgnoreCase
)

$AudioExtensions = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@(
        '.flac', '.wav', '.aiff', '.aif', '.dsf', '.dff',
        '.mp3', '.m4a', '.aac', '.ogg', '.opus', '.wma'
    ),
    [System.StringComparer]::OrdinalIgnoreCase
)

$ImageExtensions = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@(
        '.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif', '.tif', '.tiff'
    ),
    [System.StringComparer]::OrdinalIgnoreCase
)

$DocumentExtensions = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@(
        '.pdf', '.doc', '.docx'
    ),
    [System.StringComparer]::OrdinalIgnoreCase
)

# ---------- Counters ----------

$MovedAudio = 0
$MovedImages = 0
$MovedDocuments = 0
$MovedInfo = 0
$SkippedAudio = 0
$RemovedFolders = 0

# ---------- Path handling ----------

if ([string]::IsNullOrWhiteSpace($AlbumPath)) {
    $AlbumPath = (Get-Location).Path
}
else {
    # Unreal Commander can pass weird escaped / padded paths.
    $AlbumPath = $AlbumPath.Trim(' ', '"')
    $AlbumPath = (Resolve-Path -LiteralPath $AlbumPath).Path
}

# ---------- Helpers ----------

$EscapedDiscNames = $DiscFolderNames | ForEach-Object {
    [regex]::Escape($_)
}

$Script:DiscFolderPattern =
    '^\s*(?:' + ($EscapedDiscNames -join '|') + ')\s*0*(\d+)\s*$'

function Get-DiscNumber {
    param([string]$Name)

    if ($Name -match $Script:DiscFolderPattern) {
        return [int]$matches[1]
    }

    return $null
}

function Get-TrackParts {
    param([string]$BaseName)

    if ($BaseName -match '^\s*(\d+)\s*[-._ ]+\s*(.+)$') {
        $rawTrack = $matches[1]

        return [pscustomobject]@{
            Track       = [int]$rawTrack
            TrackRaw    = $rawTrack
            TrackDigits = $rawTrack.Length
            Title       = $matches[2].Trim()
        }
    }

    return [pscustomobject]@{
        Track       = $null
        TrackRaw    = $null
        TrackDigits = $null
        Title       = $BaseName.Trim()
    }
}

function Get-UniquePath {
    param(
        [string]$Directory,
        [string]$BaseName,
        [string]$Extension
    )

    $candidate = Join-Path -Path $Directory -ChildPath ($BaseName + $Extension)
    $i = 2

    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path -Path $Directory -ChildPath ("$BaseName ($i)$Extension")
        $i++
    }

    return $candidate
}

function Move-LibraryFile {
    param(
        [System.IO.FileInfo]$File,
        [string]$TargetBaseName,
        [string]$Kind,
        [ConsoleColor]$Color,
        [ref]$Counter
    )

    $targetPath = Get-UniquePath `
        -Directory $AlbumPath `
        -BaseName $TargetBaseName `
        -Extension $File.Extension

    Write-Host ("[{0}] " -f $Kind) -ForegroundColor $Color -NoNewline
    Write-Host "$($File.Name) -> $(Split-Path -Path $targetPath -Leaf)"

    if ($Execute) {
        Move-Item -LiteralPath $File.FullName -Destination $targetPath
    }

    $Counter.Value++
}

function Remove-LibraryDiscFolder {
    param(
        [pscustomobject]$DiscFolder,
        [ref]$Counter
    )

    Write-Host "[FOLDER] " -ForegroundColor DarkGray -NoNewline

    if ($Execute) {
        Write-Host "Removing $($DiscFolder.Name)"
        Remove-Item -LiteralPath $DiscFolder.Path -Recurse -Force
    }
    else {
        Write-Host "Would remove $($DiscFolder.Name)"
    }

    $Counter.Value++
}

function Start-Waiting {
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Yellow

    while ($true) {
        if ($Host.UI.RawUI.KeyAvailable) {
            [void]$Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
            break
        }
    }
}

# ---------- Find disc folders ----------

$DiscFolders = Get-ChildItem -LiteralPath $AlbumPath -Directory |
    ForEach-Object {
        $discNo = Get-DiscNumber $_.Name

        if ($null -ne $discNo) {
            [pscustomobject]@{
                Path = $_.FullName
                Name = $_.Name
                Disc = $discNo
            }
        }
    } |
    Sort-Object Disc

if (-not $DiscFolders) {
    Write-Host "No disc/cd/disk folder found in album folder: $AlbumPath" -ForegroundColor Yellow
    Start-Waiting
    return
}

$MaxDisc = ($DiscFolders | Measure-Object Disc -Maximum).Maximum
$DiscDigits = $MaxDisc.ToString().Length

if ($MaxDisc -lt 10) {
    $DiscDigits = 1
}

# ---------- Header ----------

Write-Host "Album folder : '$AlbumPath'"
Write-Host "Max disc num : $MaxDisc"
Write-Host "Disc digits  : $DiscDigits"
Write-Host ""
Write-Host "Found disc folders:" -ForegroundColor White

$DiscFolders | ForEach-Object {
    Write-Host "  $($_.Name)"
}

# ---------- Main processing ----------

foreach ($discFolder in $DiscFolders) {
    Write-Host ""
    Write-Host "Processing: $($discFolder.Name)" -ForegroundColor White

    $files = Get-ChildItem -LiteralPath $discFolder.Path -File | Sort-Object Name

    $audioFiles = $files | Where-Object {
        $AudioExtensions.Contains($_.Extension)
    }

    $imageFiles = $files | Where-Object {
        $ImageExtensions.Contains($_.Extension)
    }

    $documentFiles = $files | Where-Object {
        $DocumentExtensions.Contains($_.Extension)
    }

    $infoFiles = $files | Where-Object {
        $_.Name -ieq 'info.txt'
    }

    $DiscPrefix = $discFolder.Disc.ToString("D$DiscDigits")

    foreach ($file in $audioFiles) {
        $parts = Get-TrackParts $file.BaseName

        if ($null -eq $parts.Track) {
            Write-Host "[SKIP] " -ForegroundColor Red -NoNewline
            Write-Host "Audio file has no track number: $($file.Name)"
            $SkippedAudio++
            continue
        }

        $TrackDigits = $parts.TrackDigits

        if ($null -eq $TrackDigits -or $TrackDigits -lt 2) {
            $TrackDigits = 2
        }

        $newBaseName = "{0}{1} - {2}" -f `
            $DiscPrefix,
            $parts.Track.ToString("D$TrackDigits"),
            $parts.Title

        Move-LibraryFile `
            -File $file `
            -TargetBaseName $newBaseName `
            -Kind "AUDIO" `
            -Color Green `
            -Counter ([ref]$MovedAudio)
    }

    foreach ($file in $imageFiles) {
        $cleanBase = $file.BaseName.Trim()

        if ([string]::IsNullOrWhiteSpace($cleanBase)) {
            $cleanBase = "folder"
        }

        $newBaseName = "$($discFolder.Name)-$cleanBase"

        Move-LibraryFile `
            -File $file `
            -TargetBaseName $newBaseName `
            -Kind "IMAGE" `
            -Color Cyan `
            -Counter ([ref]$MovedImages)
    }

    foreach ($file in $documentFiles) {
        $cleanBase = $file.BaseName.Trim()

        if ([string]::IsNullOrWhiteSpace($cleanBase)) {
            $cleanBase = "document"
        }

        $newBaseName = "$($discFolder.Name)-$cleanBase"

        Move-LibraryFile `
            -File $file `
            -TargetBaseName $newBaseName `
            -Kind "DOC" `
            -Color Yellow `
            -Counter ([ref]$MovedDocuments)
    }

    foreach ($file in $infoFiles) {
        $newBaseName = "$($discFolder.Name)-info"

        Move-LibraryFile `
            -File $file `
            -TargetBaseName $newBaseName `
            -Kind "INFO" `
            -Color Magenta `
            -Counter ([ref]$MovedInfo)
    }

    Remove-LibraryDiscFolder `
        -DiscFolder $discFolder `
        -Counter ([ref]$RemovedFolders)
}

# ---------- Summary ----------

Write-Host ""
Write-Host "========================================" -ForegroundColor Green

if ($Execute) {
    Write-Host "Summary" -ForegroundColor White
}
else {
    Write-Host "Dry-run summary - would do this:" -ForegroundColor White
}

Write-Host ("Audio files     : {0,4}" -f $MovedAudio)      -ForegroundColor Green
Write-Host ("Image files     : {0,4}" -f $MovedImages)     -ForegroundColor Cyan
Write-Host ("Document files  : {0,4}" -f $MovedDocuments)  -ForegroundColor Yellow
Write-Host ("Info files      : {0,4}" -f $MovedInfo)       -ForegroundColor Magenta
Write-Host ("Skipped audio   : {0,4}" -f $SkippedAudio)    -ForegroundColor Red
Write-Host ("Disc folders    : {0,4}" -f $RemovedFolders)  -ForegroundColor DarkGray

Write-Host "========================================" -ForegroundColor Green

if ($Execute) {
    Write-Host "Done. Files were moved up to the album folder." -ForegroundColor Green
}
else {
    Write-Host "Dry-run only. Real run:" -ForegroundColor Yellow
    Write-Host ".\Remove-DiscFolders.ps1 -Execute"
}

Start-Waiting