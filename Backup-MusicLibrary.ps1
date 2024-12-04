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
		# Prompt for user input
		$input = Read-Host "Enter SourcePath|DestinationPath or type 'done'"

		if ($input -eq 'done') {
			break
		}

		# Validate the input format
		if ($input -notmatch '.*\|.*') {
			Write-Output "Invalid format. Please enter in the format 'SourcePath|DestinationPath'."
			continue
		}

		$pathPairs += $input
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
    # return Get-Content -Path $configFile
}

function Convert-ShortcutToUNC {
    Get-Content -Path $lnkFileListPath | ForEach-Object {
        $originalLnkPath = $_.Trim()

        # Find the matching source-destination pair
        $matchedSourcePath = $pathPairs.Keys | Where-Object { $originalLnkPath -like "$_*" }
        if ($matchedSourcePath) {
            $relativeTargetPath = ""

            # Load the existing shortcut to read its properties
            $shortcut = $shell.CreateShortcut($originalLnkPath)
            $relativeTargetPath = $shortcut.TargetPath

            # Convert relative path to UNC path based on matched source-destination pair
            $uncTargetPath = Join-Path -Path $pathPairs[$matchedSourcePath] -ChildPath (Resolve-Path -Path (Join-Path -Path $matchedSourcePath -ChildPath $relativeTargetPath)).TrimStart($matchedSourcePath)

            # Define the path where the new shortcut will be created on the SMB share
            $newLnkPath = $originalLnkPath.Replace($matchedSourcePath, $pathPairs[$matchedSourcePath])

            # Ensure the destination directory exists on the SMB share
            $newLnkDirectory = Split-Path -Path $newLnkPath
            if (!(Test-Path -Path $newLnkDirectory)) {
                New-Item -ItemType Directory -Path $newLnkDirectory -Force
            }

            # Create the new shortcut on the SMB share with the UNC target path
            $newShortcut = $shell.CreateShortcut($newLnkPath)
            $newShortcut.TargetPath = $uncTargetPath
            $newShortcut.WorkingDirectory = (Split-Path -Path $uncTargetPath)
            $newShortcut.Save()

            Write-Output "Created UNC shortcut at $newLnkPath with target $uncTargetPath"
        } else {
            Write-Output "No matching source path found for $originalLnkPath"
        }
    }

    Write-Output "Shortcut conversion to UNC paths completed."
}
#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
#sScriptVersion = "0.0"
# Path to configuration file
$configFile = "$env:USERPROFILE\MusicTools\SourceDestinationPairs.txt"
if (!(Test-Path $configFile)) {Get-PathPairs} else {Write-Output "Configuration file $configFile already exists. Proceeding..."}
    # Write-Output "Configuration file $configFile does not exist, exiting..."
    # Exit
# }
$outputLnkFileList = "$env:USERPROFILE\MusicTools\AllLnkFiles.txt"

#-----------------------------------------------------------[Execution]------------------------------------------------------------
# Clear previous content in the output list file
if (Test-Path $outputLnkFileList) {
    Clear-Content -Path $outputLnkFileList
}

# $pathPairs = @{}
# Get-Content -Path $configFile | ForEach-Object {
#     $paths = $_ -split '\|'
#     $sourceBasePath = $paths[0].Trim()
#     $networkBasePath = $paths[1].Trim()
#     $pathPairs[$sourceBasePath] = $networkBasePath
# }

# Loop through each line in the configuration file
Get-Content -Path $configFile | ForEach-Object {
    # Split each line into source and destination paths
    $paths = $_ -split '\|'
    $sourcePath = $paths[0].Trim()
    $destinationPath = $paths[1].Trim()
    Write-Output "$sourcePath = $destinationPath"

    # Run robocopy for each source-destination pair
    Write-Output "Copying from $sourcePath to $destinationPath..."
    #Start-Process -FilePath "robocopy.exe" -ArgumentList "`"$sourcePath`" `"$destinationPath`" /E /XF *.lnk" -NoNewWindow -Wait

    # Append each .lnk file found to the output list file
    Get-ChildItem -LiteralPath $sourcePath -Filter "*.lnk" -Recurse | ForEach-Object {
        $_.FullName | Out-File -FilePath $outputLnkFileList -Append
    }

    #Convert-ShortcutToUNC $sourcePath $outputLnkFileList
}

