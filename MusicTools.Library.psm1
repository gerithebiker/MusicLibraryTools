# MusicTools.Library.psm1
# Module to hold reusable functions for the MusicTools project

# Function to update the Unreal Commander toolbar buttons file with the current user's ID
function Update-UnrealCommanderToolbarButtons {
    param (
        [string]$IniFilePath,
        [string]$TempIniFilePath
    )

    # Get the current user's ID
    $CurrentUserId = $env:USERNAME

    # Read the file content
    $FileContent = Get-Content -Path $TempIniFilePath

    # Replace 'UserID' with the current user's ID
    $UpdatedContent = $FileContent -replace 'UserID', $CurrentUserId

    # Write the updated content back to the file
    Set-Content -Path $IniFilePath -Value $UpdatedContent
    Remove-Item -Path $TempIniFilePath -Force
    Write-Host "Updated 'UserID' in the file '$FilePath' to '$CurrentUserId'."
}

# Function to wait for user input, used for pausing the script
function Start-Waiting {
    Write-Host -ForegroundColor Yellow "Press any key to continue..."
    while ($true) {
        if ($Host.UI.RawUI.KeyAvailable) {
            [void]$Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
            break
        }
    }   
}

# Function to create a configuration file with source and destination path pairs.
function Set-ConfigFile {
    param (
        [string]$configFilePath  # Path to the configuration file
    )

    $pathPairs = @()
    $pathPairs += "# SourcePath|DestinationPath file created by Install-MusicTools script." 
    $counter = 1

    while ($true) {
        # Prompt for SourcePath
        $sourcePath = Read-Host "Enter SourcePath number $counter or type 'done' or hit enter"

        if ($sourcePath -eq 'done' -or $sourcePath -eq '') {
            break
        }

        # Validate SourcePath exists
        if (-not (Test-Path -Path $sourcePath)) {
            Write-Host -ForegroundColor Red "SourcePath '$sourcePath' does not exist. Please try again."
            continue
        }

        # Prompt for DestinationPath
        $destinationPath = Read-Host "Enter DestinationPath number ${counter}"

        # Validate DestinationPath exists
        if (-not (Test-Path -Path $destinationPath)) {
            Write-Host -ForegroundColor Red "DestinationPath '$destinationPath' does not exist. Please try again."
            continue
        }

        # Add the validated path pair to the array
        $pathPairs += "$sourcePath|$destinationPath"
        $counter++
    }

    # Write path pairs to the config file
    if ($pathPairs.Count -gt 0 -and $pathPairs[0] -ne '# SourcePath|DestinationPath file created by Install-MusicTools script.') {
        $pathPairs | Out-File -FilePath $configFilePath -Encoding UTF8
        Write-Output "Configuration file created at $configFilePath with the following entries:"
        $pathPairs | ForEach-Object { Write-Output $_ }
    } else {
        Write-Output "No valid path pairs were entered. Exiting..."
    }
    return
}