<#
.SYNOPSIS
    Verifies all the symbolic links and junctions in the given folder.

.DESCRIPTION
    This script was designed to use with "Commanders", like Unreal Commander, but works fine in command line.
    It will verify all the lnk files in a dirve, and print out if the target is relative or absolute.

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
    Get-IfRelativeLink.ps1 -w "C:\myFolder\myMusic" 
  
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
function Get-IsSymbolicLinkRelative {
    param (
        [string]$linkPath  # Path to the symbolic link or junction
    )

    # Get the link target
    $linkTarget = (Get-Item -Path $linkPath).Target

    # Check if the link target is relative or absolute
    if ($linkTarget -match '^[a-zA-Z]:\\' -or $linkTarget -match '^\\\\') {
        Write-Output "Absolute"
    } else {
        Write-Output "Relative"
    }
}

function Get-IsLnkFileRelative {
    param (
        [string]$shortcutPath  # Path to the .lnk file
    )

    # Create a Shell COM object and load the shortcut
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)

    # Get the target path
    $targetPath = $shortcut.TargetPath

    # Check if the target path is relative or absolute
    if ($targetPath -match '^[a-zA-Z]:\\' -or $targetPath -match '^\\\\') {
        Write-Output "Absolute"
    } else {
        Write-Output "Relative"
    }
}

# Exe
$runTimeTXT = "Runtime: "
$startTime = Get-Date

Get-ChildItem -LiteralPath $workingDir -Recurse | ForEach-Object {
    if ($_.Extension -eq ".lnk") {
        Write-Output "$($_.FullName) is $(Get-IsLnkFileRelative -shortcutPath $_.FullName)"
    } elseif ($_.Attributes -match "ReparsePoint") {
        Write-Output "$($_.FullName) is $(Get-IsSymbolicLinkRelative -linkPath $_.FullName)"
    }
}

$endTime = Get-Date
$runTime = [Math]::Round((New-TimeSpan -Start $startTime -end $endTime).totalseconds,2)
Write-Host $runTimeTXT$runTime "seconds."
Start-Waiting