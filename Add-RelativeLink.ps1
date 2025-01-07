<#
.SYNOPSIS
  Creates a relative link into the passive directory, using the DirName parameter.

.DESCRIPTION
  You can use this script directly, but it was designed to use with a tool like Unreal Commander, or Total Commander.
  Best way to use it, is to create a button, and assign this script to it. When you click on the button, the commander will pass the working
    directory, and the target directory to the script. The script will create a relative link in the working directory, pointing to the target directory.
    The script will check if the working directory is on a network drive, and if so, it will exit. It will also check if the target directory is in an album directory.
    If not, it will exit. The script will create a junction, not a symbolic link, because the junction is more versatile, and can be used on directories.
    The script will create a link with the following format: "Artist, Album.lnk". The script will also check if the working and target directories are on the same drive.
    If not, it will exit.
  If you set the button in the commander to run the script, you can use it with a single click. It is VERY important to
    strictly use the following format in the Commander configuration:

    Execute command: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
    Icon file: <chose what you like>
    Start path: C:\Users\<YourUserID>\MusicTools\
    Parameters: C:\Users\<YourUserID>\MusicTools\Add-RelativeLink.ps1 -w \"%T \"  -t \"%P%N\ \"
    
    With this last setting it will create the link in the PASSIVE panel. The advantage of this, if you want to create
       many links, it is easier to just select the directories one-by-one, create the link, and step to the next one.
    
    Parameters: C:\Users\<YourUserID>\MusicTools\Add-RelativeLink.ps1 -w \"%P \"  -t \"%T \"

    With the second parameters setting the link will be created in the ACTIVE panel. This is useful if you want to create
       links in a single directory.

.PARAMETER DirName
	The name of the directory where you want the link to be created

.PARAMETER Target
	Target name, where you want the link to point to
    
.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        0.9
  Author:         Geri
  Creation Date:  2024.05.24
  Purpose/Change: 2025.01.07 - Making ready for sharing

.EXAMPLE
  Create_RelativeLink -t C:\myPath\myTarget -w C:\secondPath\Directory\whereToPutTheLink
  
#>

#-------------------------------------------------------[Parameter Handling]-------------------------------------------------------


[CmdletBinding()] # For using the common parameters
    Param (
		[Parameter(Mandatory=$true)]
		[string]$targetDirectory,
		[string]$workingDir 
	)

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
#sScriptVersion = "0.0"

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

function Get-RelativePath {
    param (
        [string]$fromPath,
        [string]$toPath
    )

    # Trim any trailing backslashes
    $fromPath = $fromPath.TrimEnd('\')
    $toPath = $toPath.TrimEnd('\')

    # Split paths into arrays by directory levels
    $fromParts = $fromPath -split '\\'
    $toParts = $toPath -split '\\'

    # Find common path length
    $i = 0
    while ($i -lt $fromParts.Length -and $i -lt $toParts.Length -and $fromParts[$i] -eq $toParts[$i]) {
        $i++
    }

    # Calculate how many directories to go up from $fromPath
    $upLevels = $fromParts.Length - $i
    $relativeParts = @()
    
    # Add "..\" for each level up to the common path
    for ($j = 0; $j -lt $upLevels; $j++) {
        $relativeParts += ".."
    }

    # Add remaining parts of $toPath to form the relative path
    $relativeParts += $toParts[$i..($toParts.Length - 1)]

    # Join parts with backslashes to form the final relative path
    $relativePath = [System.IO.Path]::Combine($relativeParts -join [System.IO.Path]::DirectorySeparatorChar)
    $relativePath = $relativePath -replace '\[', '`[' -replace '\]', '`]'  # Escape square brackets
    return $relativePath
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------
# First we check if the drive is network or local
$myDrive = Get-PSDrive -Name $workingDir.Substring(0,1)
if ($myDrive.DisplayRoot -like "\\*") {
    Write-Host -ForegroundColor Red "Drive ${myDrive}: is a network drive. Exiting..."
    Start-Waiting
    Exit 1
}
# This script is designed to use with Unreal Commander, or Total Commander
# When the script is called, the commanders pass an extra space at the end of the working directory, we have to cut that off
$targetDirectory = $targetDirectory -replace '.$'
$workingDir = $workingDir -replace '.$'
Set-Location -LiteralPath $workingDir

$targetArray = $targetDirectory.split("\")
if($targetArray.Length -lt 4){
    write-host "On the 'target' side you are not in an album directory. Exiting..."
    Start-Waiting
    Exit 1
}
$workingArray = $workingDir.split("\")
$artist = $targetArray[$targetArray.length - 3] -replace " \{.*\}", ""
$linkName = $workingDir+$artist+", "+$targetArray[$targetArray.length - 2]+".lnk" 
function New-RelativeShortcut {
    param (
        [string]$shortcutPath,  # Path to where the .lnk shortcut should be created
        [string]$relativeTarget  # Relative path to the target file or folder
    )

    # Create a Shell COM object
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)

    # Set the shortcut properties
    $shortcut.TargetPath = $relativeTarget  # Relative path to target
    $shortcut.WorkingDirectory = (Get-Location).Path  # Optional: Set current directory as working directory

    # Save the shortcut
    $shortcut.Save()
}

if($workingArray[0] -ne $targetArray[0]){
	Write-Output "Must be on the same drive. Exiting..."
	Start-Waiting
	exit
} else {
	# 
    Set-Location -LiteralPath $workingDir
    $relativePath = Get-RelativePath -fromPath $workingDir -toPath $targetDirectory
	#New-Item -ItemType SymbolicLink -Path $linkName -Target $relativePath #-LiteralPath
    New-Item -ItemType Junction -Path $linkName -Target "$relativePath" 
}

# Confirm creation
if (Test-Path -LiteralPath $linkName) {
    Write-Output "Symbolic link created successfully."
} else {
    Write-Host -ForegroundColor Red -BackgroundColor Blue "`nFailed to create symbolic link.`nPress any key to exit..."
    Start-Waiting
}
