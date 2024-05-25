<#
.SYNOPSIS
  Creates a relative link using the DirName parameter

.DESCRIPTION
  It will create a relative link

.PARAMETER DirName
	The name of the directory

.PARAMETER Target
	Target name
    

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
  Create_RelativeLink dir Target
  
#>

#-------------------------------------------------------[Parameter Handling]-------------------------------------------------------

    [CmdletBinding()] # For using the common parameters
    Param (
		[Parameter(Mandatory=$true)]
		[string]$targetDirectory,
		[string]$workingDir
	)



#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#Dot Source required Function Libraries. It is not defined yet
#. "Path\Library.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "0.0"

#Log File Info
$sLogPath = "$env:homedrive$env:homepath\Temp"
<#
#Checking logpath
if(!(Test-Path -Path $sLogPath )){
    New-Item -ItemType directory -Path $sLogPath
}#>

$sLogName = $MyInvocation.MyCommand.Name.Split('.')[0]
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Functions]------------------------------------------------------------

<#
Function <FunctionName>{
  Param()

  Begin{
    Log-Write -LogPath $sLogFile -LineValue "<description of what is going on>..."
  }

  Process{
    Try{
      <code goes here>
    }

    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }

  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}
#>

#-----------------------------------------------------------[Execution]------------------------------------------------------------

# 
Set-Location $workingDir
$targetArray = $targetDirectory.split("\")
$workingArray = $workingDir.split("\")
# $targetArray

$targetDirectory 
#$workingDir
Write-Host "devider....."
#$nameArray = $workingDir.split("\")
#$myLength = $targetArray.length - 2
$linkName = $targetArray[$targetArray.length - 2]
"workingDir: "
$workingDir
$targetArray[0]
#$nameArray
#Start-Sleep -s 10

if($workingArray[0] -ne $targetArray[0]){
	Write-Output "Must be on the same drive. Exiting..."
	Start-Sleep -s 10
	exit
} else {
	# 
	$counter = 0
	$relativeLink = ""
    #$firstHalf = ""
	for($i=1; $i -lt ($targetArray.length - 2); $i++){
		if($targetArray[$i] -eq $workingArray[$i]){
			$counter++
		} else {
            for($j=$counter + 1; $j -lt ($workingArray.length - 1); $j++){
                $relativeLink = $relativeLink + "..\"
            }
            $relativeLink = $relativeLink -replace ".$"
            for($j=$counter + 1; $j -lt ($targetArray.length - 1); $j++){
                $relativeLink = $relativeLink + "\" + $targetArray[$j]
            }
		}
	}
	Write-Host "Creating Link..." $linkName"," $relativeLink
    #$relativeLink
	New-Item -ItemType SymbolicLink -Path $linkName -Target $relativeLink
	#Start-Sleep -s 10
}

# Confirm creation
if (Test-Path $workingDir) {
    Write-Output "Symbolic link created successfully."
} else {
    Write-Output "Failed to create symbolic link."
}

Start-Sleep -s 20
