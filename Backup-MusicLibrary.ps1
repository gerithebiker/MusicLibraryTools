<#
.SYNOPSIS
  Converts a relative link from the local drive and places it into a pre-defined SMB network drive

.DESCRIPTION
  -- ToDo --

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
  Creation Date:  2024.11.11
  Purpose/Change: 

.EXAMPLE
    -- ToDo --
  
#>

#-------------------------------------------------------[Parameter Handling]-------------------------------------------------------


[CmdletBinding()] # For using the common parameters
    Param (
		# [Parameter(Mandatory=$true)]
		# [string]$targetDirectory,
		# [string]$workingDir
	)


#-----------------------------------------------------------[Functions]------------------------------------------------------------
function Get-PathPairs {
    param (
        [string]$configFile  # Path to the configuration file
    )

	$pathPairs = @()

	while ($true) {
		# Prompt for user configInput
		$configInput = Read-Host "Enter SourcePath|DestinationPath or type 'done'"

		if ($configInput -eq 'done') {
			break
		}

		# Validate the configInput format
		if ($configInput -notmatch '.*\|.*') {
			Write-Output "Invalid format. Please enter in the format 'SourcePath|DestinationPath'."
			continue
		}

		$pathPairs += $configInput
	}

	# Write path pairs to the config file
	if ($pathPairs.Count -gt 0) {
		$pathPairs | Out-File -FilePath $configFile -Encoding UTF8
		Write-Output "Configuration file created at $configFile."
	} else {
		Write-Output "No path pairs were entered. Exiting..."
		Exit
	}
    # Return the configuration file content
    return Get-Content -Path $configFile
}

function Convert-ShortcutToUNC {
    param (
        [string]$sourcePath,
        [string]$outputLnkFileList  # 
    )
    Get-Content -Path $outputLnkFileList | ForEach-Object {
        $originalLnkPath = $_.Trim()

        # Find the matching source-destination pair
        $matchedSourcePath = $pathPairs.Keys | Where-Object { $originalLnkPath -like "$_*" }
        if ($matchedSourcePath) {
            $relativeTargetPath = ""

            # Load the existing shortcut to read its properties
            $shortcut = Get-Item -Path $originalLnkPath 
            $relativeTargetPath = $($shortcut.TargetPath)

            # Convert relative path to UNC path based on matched source-destination pair
            $uncTargetPath = Join-Path -Path $pathPairs[$matchedSourcePath] -ChildPath ((Resolve-Path -Path (Join-Path -Path $matchedSourcePath -ChildPath $relativeTargetPath)).Path.TrimStart($matchedSourcePath))
            
            # Define the new target path on the SMB share
            $newTargetPath = $shortcut.Target.Replace($shortcut.Root, $uncTargetPath)

            # Define the path where the new shortcut will be created on the SMB share
            $newLnkPath = $originalLnkPath.Replace($shortcut.Root, $uncTargetPath)

            # Ensure the destination directory exists on the SMB share
            $newLnkDirectory = Split-Path -Path $newLnkPath
            if (!(Test-Path -Path $newLnkDirectory)) {
                New-Item -ItemType Directory -Path $newLnkDirectory -Force
            }

            # Create the new shortcut on the SMB share with the UNC target path
            $myShell = New-Object -ComObject WScript.Shell
            $newShortcut = $myShell.CreateShortcut($newLnkPath)
            $newShortcut.TargetPath = $newTargetPath
            $newShortcut.WorkingDirectory = $newLnkPath
            $newShortcut.Save()
        } else {
            Write-Host -ForegroundColor Red "No matching source path found for $originalLnkPath"
            while ($true) {
                if ($Host.UI.RawUI.KeyAvailable) {
                    break
                }
            }
        }
    }

    # Write-Output "Shortcut conversion to UNC paths completed."
}
#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
ScriptVersion = "0.0"

# Path to configuration file
$configFile = "$env:USERPROFILE\MusicTools\SourceDestinationPairs.txt"
if (!(Test-Path $configFile)) {Get-PathPairs} else {Write-Output "Configuration file $configFile already exists. Proceeding..."}
$outputLnkFileList = "$env:USERPROFILE\MusicTools\AllLnkFiles.txt"

#-----------------------------------------------------------[Execution]------------------------------------------------------------
# Check if robocopy exists, it is necessary for the script to run
if (-not (Get-Command -Name "robocopy" -ErrorAction SilentlyContinue)) {
    Write-Output "Robocopy is not installed. Please install it and try again."
    Exit
}

# Clear previous content in the output list file
if (Test-Path $outputLnkFileList) {
    Clear-Content -Path $outputLnkFileList
}

 $pathPairs = @{}
 Get-Content -Path $configFile | ForEach-Object {
     $paths = $_ -split '\|'
     $sourceBasePath = $paths[0].Trim()
     $networkBasePath = $paths[1].Trim()
     $pathPairs[$sourceBasePath] = $networkBasePath
}

# Loop through each line in the configuration file
Get-Content -Path $configFile | ForEach-Object {
    # Split each line into source and destination paths
    $paths = $_ -split '\|'
    $sourcePath = $paths[0].Trim()
    $sourcePath = $sourcePath + "\"
    $destinationPath = $paths[1].Trim()
    Write-Output "$sourcePath = $destinationPath"

    # Run robocopy for each source-destination pair
    Write-Output "Copying from $sourcePath to $destinationPath..."
    Start-Process -FilePath "robocopy.exe" -ArgumentList "`"$sourcePath`" `"$destinationPath`" /E /XF *.lnk /XD `"System Volume Information`" *.lnk" -NoNewWindow -Wait

    # Append each .lnk file found to the output list file
    Get-ChildItem -LiteralPath $sourcePath -Filter "*.lnk" -Recurse | ForEach-Object {
        $_.FullName | Out-File -FilePath $outputLnkFileList -Append
    }

    Convert-ShortcutToUNC $sourcePath $outputLnkFileList
}

