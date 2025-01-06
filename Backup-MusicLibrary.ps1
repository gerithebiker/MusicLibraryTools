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

function Get-ShortcutDetails {
    param (
        [string]$ShortcutPath
    )

    # Ensure the file exists
    if (-not (Test-Path -LiteralPath $ShortcutPath)) {
        throw "The shortcut file does not exist: $ShortcutPath"
    }

    # Check PowerShell version
    $psMajorVersion = $PSVersionTable.PSVersion.Major

    # Use WScript.Shell to read shortcut properties
    $myShell = New-Object -ComObject WScript.Shell
    $myHelper = $myShell.CreateShortcut($ShortcutPath)

    # Extract target and root
    $shortcutTarget = $null
    $shortcutRoot = $null

    if ($psMajorVersion -ge 7) {
        # Handle PowerShell 7.x behavior
        $shortcutTarget = $myHelper.TargetPath
        $shortcutRoot = ($myHelper.FullName -split '\\')[0] + '\'
    } elseif ($psMajorVersion -eq 5) {
        # Handle PowerShell 5.1 behavior
        try {
            $shortcutTarget = $myHelper.TargetPath
            $shortcutRoot = ($myHelper.FullName -split '\\')[0] + '\'
        } catch {
            throw "Failed to read shortcut details in PowerShell 5.1."
        }
    } else {
        throw "Unsupported PowerShell version: $psMajorVersion"
    }

    # Return details
    [PSCustomObject]@{
        TargetPath = $shortcutTarget
        RootPath   = $shortcutRoot
    }
}

function Set-ConfigFile {
    param (
        [string]$configFile  # Path to the configuration file
    )

    $pathPairs = @()

    while ($true) {
        # Prompt for SourcePath
        $sourcePath = Read-Host "Enter SourcePath or type 'done' or hit enter"

        if ($sourcePath -eq 'done' -or $sourcePath -eq '') {
            break
        }

        # Validate SourcePath exists
        if (-not (Test-Path -Path $sourcePath)) {
            Write-Host -ForegroundColor Red "SourcePath '$sourcePath' does not exist. Please try again."
            continue
        }

        # Prompt for DestinationPath
        $destinationPath = Read-Host "Enter DestinationPath"

        # Validate DestinationPath exists
        if (-not (Test-Path -Path $destinationPath)) {
            Write-Host -ForegroundColor Red "DestinationPath '$destinationPath' does not exist. Please try again."
            continue
        }

        # Add the validated path pair to the array
        $pathPairs += "$sourcePath|$destinationPath"
    }

    # Write path pairs to the config file
    if ($pathPairs.Count -gt 0) {
        $pathPairs | Out-File -FilePath $configFile -Encoding UTF8
        Write-Output "Configuration file created at $configFile with the following entries:"
        $pathPairs | ForEach-Object { Write-Output $_ }
    } else {
        Write-Output "No valid path pairs were entered. Exiting..."
    }
    return
}
function Convert-ShortcutToUNC {
    param (
        [string]$sourcePath,
        [string]$outputLnkFileList
    )

    Get-Content -Path $outputLnkFileList | ForEach-Object {
        $originalLnkPath = $_.Trim()

        # Check if the shortcut exists
        if (-not (Test-Path -LiteralPath $originalLnkPath)) {
            Write-Host -ForegroundColor Red "Shortcut file not found: $originalLnkPath"
            return
        }

        # Initialize shortcut variables
        $shortcutDetails = $null
        $shortcut = Get-Item -LiteralPath $originalLnkPath

        # Handle shortcuts differently based on their properties
        try {
            #if ($null -ne $shortcut.Target -and $shortcut.Target.Length -gt 0 -and $shortcut.Target[0].Length -eq 0) {
            #if ($shortcut.Target -and $shortcut.Target -is [System.Collections.IEnumerable] -and $shortcut.Target.Count -gt 0) {
            if ($null -ne $shortcut.Target){
                if ($shortcut.Target.Length -gt 0){
                                    # Handle basic shortcuts
                    $shortcutDetails = [PSCustomObject]@{
                        TargetPath = $shortcut.Target[0] -as [string]
                        RootPath   = ($shortcut.FullName -split '\\')[0] + '\'
                    }
                } else {
                    # Use Get-ShortcutDetails for complex cases
                    $shortcutDetails = Get-ShortcutDetails -ShortcutPath $originalLnkPath
                } 
            } else {
                # Use Get-ShortcutDetails for complex cases
                $shortcutDetails = Get-ShortcutDetails -ShortcutPath $originalLnkPath
            }  
        } catch {
            Write-Host -ForegroundColor Red "Failed to process shortcut: $originalLnkPath"
            Write-Host -ForegroundColor Red $_.Exception.Message
            Start-Waiting
            return
        }

        # Ensure $shortcutDetails is valid
        if ($null -eq $shortcutDetails -or $null -eq $shortcutDetails.TargetPath) {
            Write-Host -ForegroundColor Red "Invalid shortcut details for: $originalLnkPath"
            return
        }

        # Convert relative path to UNC path
        try {
            $matchedSourcePath = $pathPairs.Keys | Where-Object { $originalLnkPath -like "$_*" }
            if ($null -eq $matchedSourcePath) {
                Write-Host -ForegroundColor Red "No matching source path found for $originalLnkPath"
                return
            }

            # Define the new shortcut on the SMB share
            $newTargetPath = $shortcutDetails.TargetPath.Replace($shortcutDetails.RootPath, $pathPairs[$matchedSourcePath] + "\") #$uncTargetPath)
            $newLnkPath = $originalLnkPath.Replace($shortcutDetails.RootPath,  $pathPairs[$matchedSourcePath] + "\") #$uncTargetPath)

            # Ensure the destination directory exists
            $newLnkDirectory = Split-Path -Path $newLnkPath
            if (!(Test-Path -Path $newLnkDirectory)) {
                New-Item -ItemType Directory -Path $newLnkDirectory -Force
            }

            # Create the new shortcut
            $myShell = New-Object -ComObject WScript.Shell
            $newShortcut = $myShell.CreateShortcut($newLnkPath)
            $newShortcut.TargetPath = $newTargetPath
            $newShortcut.WorkingDirectory = $newLnkDirectory
            $newShortcut.Save()

            Write-Host -ForegroundColor Green "Shortcut created: $newLnkPath"
            Set-Location -Path "$($newLnkPath)"
        } catch {
            Write-Host -ForegroundColor Red "Error creating shortcut for: $originalLnkPath"
            Write-Host -ForegroundColor Red $_.Exception.Message
        }
    }
}

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
#$ScriptVersion = "0.0"

# Path to configuration file
$configFile = "$env:USERPROFILE\MusicTools\SourceDestinationPairs.txt"
if (!(Test-Path $configFile)) {Set-ConfigFile} #else {Write-Output "Configuration file $configFile already exists. Proceeding..."}
# Path to output list file for the .lnk files list
$outputLnkFileList = "$env:USERPROFILE\MusicTools\AllLnkFiles.txt"

#-----------------------------------------------------------[Execution]------------------------------------------------------------
# Check if robocopy exists, it is necessary for the script to run
if (-not (Get-Command -Name "robocopy" -ErrorAction SilentlyContinue)) {
    Write-Output "Robocopy is not installed. Please install it and try again."
    Start-Waiting
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

    # Add valid paths to the hashtable we use later to step through
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