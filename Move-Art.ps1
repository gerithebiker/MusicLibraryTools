<#
.SYNOPSIS
    Moves the "Artwork", "Scans", "Covers", or "Art" folder to the working directory, 
        and renames the files in the folder to "zArt" format. This makes sure there will
        be no files starting with numbers, that would mix up the music files with the art files.

.DESCRIPTION
    This script was designed to use with "Commanders", like Unreal Commander.

    Setting up the script in Unreal Commander:

    Execute command: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
    Icon file: <chose what you like>
    Start path: C:\Users\<YourUserID>\AppData\Roaming\MusicLibraryTools\
    Parameters: C:\Users\<YourUserID>\AppData\Roaming\MusicLibraryTools\Move-Art.ps1  -w \"%P \"

.PARAMETER workingDir
	The name of the directory where your files are

.PARAMETER fileList
	List of file names that should be corrected
    
.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Geri
  Creation Date:  2024.12.06
  Purpose/Change: 2025.01.07 - Making ready for sharing

.EXAMPLE
    Rename-toCorrectFormat.ps1 -w "C:\myFolder\myMusic" -f "1. Loud Song.flac 2. Quiet Song.flac"
  
#>
#-------------------------------------------------------[Parameter Handling]-------------------------------------------------------
[CmdletBinding()] # For using the common parameters
Param (
    [Parameter(Mandatory=$true)]
    [string]$workingDir
)

#-----------------------------------------------------------[Config]------------------------------------------------------------

$ArtworkFolderNames = @(
    "Artwork",
    "Artworks",
    "Art Works",
    "Scans",
    "Scan",
    "Covers",
    "Cover",
    "Art",
    "Pictures",
    "Pics",
    "Extras",
    "BlowArt",
    "booklet"
)

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Start-Waiting {
    Write-Host -ForegroundColor Yellow "Press any key to continue..."
    while ($true) {
        if ($Host.UI.RawUI.KeyAvailable) {
            [void]$Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
            break
        }
    }
}

function Find-ArtworkFolder {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDir,

        [Parameter(Mandatory)]
        [string[]]$FolderNames
    )

    foreach ($folder in $FolderNames) {
        $candidate = Join-Path -Path $WorkingDir -ChildPath $folder

        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

#-----------------------------------------------------------[Main]------------------------------------------------------------

# For some reason "Unreal Commander" puts a space character at the end of the path, we have to cut it off...
# If you are using the script from command line, or possibly from another commander, you might need to comment out this line
$workingDir = $workingDir -replace ' ?$'

$artPath = Find-ArtworkFolder -WorkingDir $workingDir -FolderNames $ArtworkFolderNames

if (-not $artPath) {
    Write-Host -ForegroundColor Red @"

There is no artwork folder.

Supported folder names are:
$($ArtworkFolderNames -join ', ')

Press any key to exit...

"@

    # Start-Waiting
    Exit
}

# For tshooting
# Write-Host "Working Dir: $workingDir"
# Write-Host "ArtPath: $artPath"

# Get all files in the artwork folder
$files = Get-ChildItem -LiteralPath $artPath -Filter "*"

# Move each file
foreach ($file in $files) {
    if ($file.Name -match '^[\d ]' ) {
        $newName = $file.Name -replace '^', 'z'
    } else {
        $newName = $file.Name
    }
    $newName = Join-Path -Path $workingDir -ChildPath $newName

    Move-Item -LiteralPath $file.FullName -Destination $newName
}

# Now we remove the not needed empty folder
Remove-Item -LiteralPath $artPath

# For tshooting, or if you just want to see the messages, uncomment the following line
# Start-Waiting