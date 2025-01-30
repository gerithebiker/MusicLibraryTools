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
    if ($pathPairs.Count -gt 1) {
        $pathPairs | Out-File -FilePath $configFilePath -Encoding UTF8
        Write-Output "Configuration file created at $configFilePath with the following entries:"
        $pathPairs | ForEach-Object { Write-Output $_ }
    } else {
        Write-Output "No valid path pairs were entered. Exiting..."
    }
    return
}

function Convert-TextToExcel {
    param (
        [string]$InputFile,
        [string]$OutputFile
    )

    # Ensure ImportExcel module is installed
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Error "The ImportExcel module is not installed. Install it using: Install-Module -Name ImportExcel"
        return
    }

    # Ensure the input file exists
    if (!(Test-Path $InputFile)) {
        Write-Error "Input file not found: $InputFile"
        return
    }

    # Read the text file
    $lines = Get-Content -Path $InputFile

    # Prepare data for Export-Excel
    $data = @()

    # Read and process each line from the input file
    Get-Content -Path $InputFile | ForEach-Object {
        $item = New-Object PSObject
        if ($_ -match "^\s{4}") {
            $item | Add-Member -MemberType NoteProperty -Name "Path" -Value ""
            $item | Add-Member -MemberType NoteProperty -Name "FileName" -Value $_.TrimStart()
        } else {
            $item | Add-Member -MemberType NoteProperty -Name "Path" -Value $_
            $item | Add-Member -MemberType NoteProperty -Name "FileName" -Value ""
        }
        $data += $item
    }

    # Export the data to Excel using Export-Excel with -AutoSize, -FreezeTopRow, and -BoldTopRow
    $data | Export-Excel -Path $OutputFile -AutoSize -FreezeTopRow -BoldTopRow -TableName "Data"

    Write-Host "Excel file created successfully: $OutputFile"
}

function Get-PartialFileHash {
    param (
        [string]$FilePath,
        [int]$BytesToRead = 1MB  # Default: Read first 1MB
    )

    try {
        # Just indicating that the function is running
        Write-Host "Function 'Get-PartialFileHash' is hashing file: $FilePath" -ForegroundColor Green
        # ✅ Normalize path to handle special characters
        $normalizedPath = [System.IO.Path]::GetFullPath($FilePath)

        # ✅ Open file safely with full path handling
        $stream = [System.IO.File]::Open($normalizedPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $buffer = New-Object byte[] $BytesToRead
        $bytesRead = $stream.Read($buffer, 0, $BytesToRead)  # Read the first X bytes
        $stream.Close()

        # Compute SHA-256 hash on the partial buffer
        $hash = (New-Object Security.Cryptography.SHA256Managed).ComputeHash($buffer[0..($bytesRead-1)])
        return -join ($hash | ForEach-Object { $_.ToString("x2") })  # Convert to hex string
    }
    catch {
        Write-Warning "Function 'Get-PartialFileHash' error hashing file: $FilePath - $_" -ForegroundColor Red
        return $null  # Return null if there's an error
    }
}
