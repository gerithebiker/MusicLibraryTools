<#
.SYNOPSIS
  Creates a relative link into the current directory, using the DirName parameter

.DESCRIPTION
  You can use this script directly, but it was designed to use with a tool like Unreal Commander, or Total Commander. 

.PARAMETER DirName
	The name of the directory where you want the link to be created

.PARAMETER Target
	Target name, where you want the link to point to
    
.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        0.1
  Author:         Geri
  Creation Date:  2024.05.24
  Purpose/Change: First working version

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

#-----------------------------------------------------------[Execution]------------------------------------------------------------
Write-Host "Stuff"
$targetDirectory
$workingDir
$linkName 
Start-Sleep -s 20

Set-Location  $workingDir #-LiteralPath
$targetArray = $targetDirectory.split("\")
$workingArray = $workingDir.split("\")
$linkName = $targetArray[$targetArray.length - 2] #$workingDir + 


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
    return $relativePath
}

if($workingArray[0] -ne $targetArray[0]){
	Write-Output "Must be on the same drive. Exiting..."
	Start-Sleep -s 10
	exit
} else {
	# 
    Set-Location $workingDir
    $relativePath = Get-RelativePath -fromPath $workingDir -toPath $targetDirectory
    Write-Host "Relative Path: " $relativePath
    Write-Host "Creating Link..." $linkName",##" $relativePath

	New-Item -ItemType SymbolicLink -Path $linkName -Target $relativePath #-LiteralPath
	#Start-Sleep -s 10
}

# Confirm creation
if (Test-Path $workingDir) {
    Write-Output "Symbolic link created successfully."
} else {
    Write-Output "Failed to create symbolic link."
}

Start-Sleep -s 290
