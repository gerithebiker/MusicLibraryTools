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

Set-Location -LiteralPath $workingDir
$targetArray = $targetDirectory.split("\")
$workingArray = $workingDir.split("\")
$linkName = $targetArray[$targetArray.length - 2]

$targetDirectory
$workingDir
$linkName

if($workingArray[0] -ne $targetArray[0]){
	Write-Output "Must be on the same drive. Exiting..."
	Start-Sleep -s 10
	exit
} else {
	# 
	$counter = 0
	$relativeLink = ""
    #$firstHalf = ""
	for($i=1; $i -lt ($targetArray.length - 1); $i++){
		if($targetArray[$i] -eq $workingArray[$i]){
			$counter++
		} else {
            for($j=$counter; $j -lt ($workingArray.length - 1); $j++){
                $relativeLink = $relativeLink + "..\"
                $relativeLink
            }
            $relativeLink = $relativeLink -replace ".$"
            $relativeLink
            for($j=$counter; $j -lt ($targetArray.length - 1); $j++){
                $relativeLink = $relativeLink + "\" + $targetArray[$j]
                $relativeLink
            }
		}
	}
	Write-Host "Creating Link..." $linkName"," $relativeLink
    #$linkName = [Regex]::Escape($linkName) #$linkName -replace '[+(),\\.]{}','\$&'
    Write-Host "Creating Link..." $linkName",##" $relativeLink
    #$relativeLink
	New-Item -ItemType SymbolicLink -Path '$linkName' -Target '$relativeLink' #-LiteralPath
	#Start-Sleep -s 10
}

# Confirm creation
if (Test-Path $workingDir) {
    Write-Output "Symbolic link created successfully."
} else {
    Write-Output "Failed to create symbolic link."
}

Start-Sleep -s 20
