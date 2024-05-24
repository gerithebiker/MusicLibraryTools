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
  Version:        0.0
  Author:         Geri
  Creation Date:  2024.05.23
  Purpose/Change: Initial script development

  

.EXAMPLE
  Create_RelativeLink dir Target
  
#>

#-------------------------------------------------------[Parameter Handling]-------------------------------------------------------

    [CmdletBinding()] # For using the common parameters
    Param (
		[string]$DirName,
		[string]$Target
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

$targetArray = $Target.split("\")
$targetArray
$nameArray = $DirName.split("\")
write-host "---"
$nameArray
$in = Read-Host "Itt> "

#This message displayed only if the script called with the "-Verbose" switch
Write-Verbose -Message "<Message comes here.>"



#Log-Finish -LogPath $sLogFile
