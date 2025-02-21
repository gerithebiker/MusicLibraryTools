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

#-----------------------------------------------------------[Main]------------------------------------------------------------
# Ensure the working directory ends with a backslash
# In "Unreal Commander" it is not necessary, uncomment if needed.
#if (-not $workingDir.EndsWith("\")) {
#    $workingDir += "\"
#}

# For some reason "Unreal Commander" puts a space character at the end of the path, we have to cut it off...
# If u using the script from command line, or possibly from other commander, you might need to comment out this line
$workingDir = $workingDir -replace ' ?$'
# Write-Host "Working Dir: $workingDir"
$artPath = $null

switch ($true) {
    { Test-Path -LiteralPath "$workingDir\Artwork" }  { $artPath = Join-Path -Path $workingDir -ChildPath "Artwork"; break }
    { Test-Path -LiteralPath "$workingDir\Artworks" } { $artPath = Join-Path -Path $workingDir -ChildPath "Artworks"; break }
    { Test-Path -LiteralPath "$workingDir\scans" }    { $artPath = Join-Path -Path $workingDir -ChildPath "Scans"; break }
    { Test-Path -LiteralPath "$workingDir\covers" }   { $artPath = Join-Path -Path $workingDir -ChildPath "Covers"; break }
    { Test-Path -LiteralPath "$workingDir\art" }      { $artPath = Join-Path -Path $workingDir -ChildPath "Art"; break }
    default {
        Write-Host -ForegroundColor Red "`nThere is no 'Scans', 'Artwork', 'Art', or 'Covers' folder.`nPress any key to exit..."
        Start-Waiting
        Exit
    }
}

# For tshooting
# Write-Host "Working Dir: $workingDir"
# Write-Host "ArtPath: $artPath"

# Get all files in the folder (supports wildcards) using Get-ChildItem
$files = Get-ChildItem -LiteralPath $artPath -Filter "*"

# Move each file. "LiteralPath" cannot use wildcard, that is why we had to put together this list, and do one-by-one
foreach ($file in $files) {
	$newName = $file.Name -replace '^', 'zArt'
	$newName = Join-Path -Path $workingDir -ChildPath $newName
    Move-Item -LiteralPath $file.FullName -Destination $newName
}

# Now we remove the not needed empty folder
Remove-Item -LiteralPath $artPath 

# For tshooting, or if you just want to see the messages, uncomment the following line
# Start-Waiting