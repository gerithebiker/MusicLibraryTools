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
# This script does not use the common parameters, as it is not designed to be used in a pipeline,
#   but with a tool like Unreal Commander, or Total Commander
# To make life easier, we will use a predefined parameter file, where we can store the parameters
# This file is stored in the user's profile directory, and it is lodated here: "$env:USERPROFILE\MusicTools\SourceDestinationPairs.txt"

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
            #$relativeTargetPath = ""

            # Load the existing shortcut to read its properties
            $shortcut = Get-Item -LiteralPath $originalLnkPath 

            # We need a two helper variables to store the target path and the root path of the shortcut
            # It is to handle the "absolute" and "relative" links differently, as they do not have the same property names,
            #   and the "absolute" links do not have the "Root" property
            # Later we will use these variables to create the new shortcut
            $shortcutTarget = "" # Initialize the target path with an empty string
            $shortcutRoot = "" # Initialize the root path with an empty string

            #$relativeTargetPath = $($shortcut.TargetPath)
            if($shortcut.Target[0].Length -eq 0){
                $myShell = New-Object -ComObject WScript.Shell
                $myHelper = $myShell.CreateShortcut($($originalLnkPath)) 
                $shortcutTarget = $myHelper.TargetPath # shortcut.Target is read-only
                $shortcutRoot = ($myHelper.FullName -split '\\')[0] + '\'
            } else {
                $shortcutTarget = $shortcut.Target
                $shortcutRoot = $shortcut.Root
            }

            # Convert relative path to UNC path based on matched source-destination pair
            $uncTargetPath = Join-Path -Path $pathPairs[$matchedSourcePath] -ChildPath ((Resolve-Path -Path (Join-Path -Path $matchedSourcePath -ChildPath $relativeTargetPath)).Path.TrimStart($matchedSourcePath))
            
            write-host $shortcutTarget " #_#_#_# " $originalLnkPath " ShortRoot: " $shortcutRoot 
            # Define the new target path on the SMB share
            $newTargetPath = $shortcutTarget.Replace($shortcutRoot, $uncTargetPath)

            # Define the path where the new shortcut will be created on the SMB share
            $newLnkPath = $originalLnkPath.Replace($shortcutRoot, $uncTargetPath)

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
            Start-Waiting
        }
    }
}
#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
#$ScriptVersion = "0.0"

# Path to configuration file
$configFile = "$env:USERPROFILE\MusicTools\SourceDestinationPairs.txt"
if (!(Test-Path $configFile)) {Get-PathPairs} else {Write-Output "Configuration file $configFile already exists. Proceeding..."}
# Path to output list file for the .lnk files list
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
Get-Content -Path $configFile | Where-Object { -not $_.TrimStart().StartsWith("#") } | ForEach-Object {
    $paths = $_ -split '\|'
    $sourceBasePath = $paths[0].Trim()
    $networkBasePath = $paths[1].Trim()

    # Error checking for each path
    if (!(Test-Path $sourceBasePath)) {
        Write-Host -NoNewline "The  source  path  does not exist: "
        Write-Host -ForegroundColor Red $sourceBasePath
        Write-Host -NoNewline "Please fix the configuration file: "
        write-host -ForegroundColor Red $configFile
        Start-Waiting
        return
    }
    if (!(Test-Path $networkBasePath)) {
        Write-Host -NoNewline "The  network  path does not exist: "
        Write-Host -ForegroundColor Red $networkBasePath
        Write-Host -NoNewline "Please fix the configuration file: "
        write-host -ForegroundColor Red $configFile
        Start-Waiting
        return
    }

    # Add valid paths to the hashtable
    $pathPairs[$sourceBasePath] = $networkBasePath
}

# Loop through each line in the configuration file
$pathPairs.GetEnumerator() | ForEach-Object {
    # Split each line into source and destination paths
    # $paths = $_ -split '\|'
    $sourcePath = $_.Key #$paths[0].Trim()
    $sourcePath = $sourcePath + "\"
    $destinationPath = $_.Value #$paths[1].Trim()

    # Run robocopy for each source-destination pair
    # Write-Output "Copying from $sourcePath to $destinationPath..."
    Start-Process -FilePath "robocopy.exe" -ArgumentList "`"$sourcePath`" `"$destinationPath`" /S /XF *.lnk /XD `"System Volume Information`" *.lnk" -NoNewWindow -Wait

    # Append each .lnk file found to the output list file
    Get-ChildItem -LiteralPath $sourcePath -Filter "*.lnk" -Recurse | ForEach-Object {
        $_.FullName | Out-File -FilePath $outputLnkFileList -Append
    }

    Convert-ShortcutToUNC $sourcePath $outputLnkFileList
}

Start-Waiting