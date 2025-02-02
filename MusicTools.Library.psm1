# MusicLibraryTools.Library.psm1
# Module to hold reusable functions for the MusicLibraryTools project

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
    $pathPairs += "# SourcePath|DestinationPath file created by Install-MusicLibraryTools script." 
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
    # $lines = Get-Content -Path $InputFile

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

    Write-ColoredText -TextPairs "Excel file created successfully: ", $OutputFile -AccentColor "Green"
}

function Get-PartialFileHash {
    param (
        [string]$FilePath,
        [int]$BytesToRead = 1MB  # Default: Read first 1MB
    )

    try {
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

function Get-ExclusionsFromINI {
    param ([string]$IniPath = ".\mTools.ini")

    # Ensure the file exists
    if (-not (Test-Path -LiteralPath $IniPath)) {
        Write-Warning "INI file not found: $IniPath"
        return @{excludeFiles=@(); excludeDirs=@()}  # Return empty exclusions if file is missing
    }

    # Read the INI content
    $iniContent = Get-Content -LiteralPath $IniPath | Where-Object { $_ -match "^\s*\[fileScanExclusions\]" -or $_ -match "^\s*(excludeFiles|excludeDirs)\s*=" }

    # Prepare storage for exclusions
    $exclusions = @{excludeFiles=@(); excludeDirs=@()}

    foreach ($line in $iniContent) {
        if ($line -match "^\s*excludeFiles\s*=\s*(.+)") {
            $exclusions["excludeFiles"] = $matches[1] -split ",\s*"  # Split by comma
        }
        elseif ($line -match "^\s*excludeDirs\s*=\s*(.+)") {
            $exclusions["excludeDirs"] = $matches[1] -split ",\s*"  # Split by comma
        }
    }

    return $exclusions
}

function Use-ProgressIndicator {
    param (
        [int]$Current,
        [int]$Total,
        [string]$Message,
        [string]$Prefix = "Processing:"
    )

    # Avoid division by zero
    if ($Total -eq 0) { return }

    # Calculate progress percentage
    $progress = [math]::Floor(($Current / $Total) * 100)

    # Get console width for dynamic formatting
    $consoleWidth = [console]::WindowWidth
    $progressText = "$Prefix $Current / $Total ($progress%)"

    # Ensure file names fit within available space
    $progressLength = $progressText.Length
    $maxTextWidth = $consoleWidth - $progressLength - 5  # Extra buffer

    # Truncate message if too long
    if ($Message.Length -gt $maxTextWidth) {
        $Message = $Message.Substring(0, $maxTextWidth - 3) + "..."
    }

    # Clear previous line & update progress
    $clearLine = "`r" + (" " * ($consoleWidth - 1)) + "`r"
    Write-Host "$clearLine`r$progressText $Message" -NoNewline -ForegroundColor Green
}

function Test-FileLocked {
    param ([string]$FilePath)
    $myFile = Resolve-Path $FilePath
    try {
        $fs = [System.IO.File]::Open($myFile, 'Open', 'Write')
        $fs.Close()
        Remove-Item -Force $FilePath
        return $false  # File is NOT locked
    } catch {
        return $true   # File is locked
    }
}

function Write-HostClearLine {
    param (
        [string]$Message,       # Message to display
        [string]$Color = "",     # Default color
        [switch]$NoNewline        # Add a newline at the end
    )
    # Ensure progress bar is cleared after processing
    $consoleWidth = [console]::WindowWidth
    $clearLine = (" " * ($consoleWidth - $message.Length)) + "`r"  # Dynamically clear the line

    # We use no new line here, an if requested, we add a newline at the end
    if($Color -eq "") {
        Write-Host "`r$message$clearLine" -NoNewline
    } else {    
        Write-Host "`r$message$clearLine" -ForegroundColor $Color -NoNewline
    }

    # Do not add new line if requested, double negative logic
    if(-not $NoNewline) {
        Write-Host
    } 
}


function Write-ColoredText {
    param (
        [string]$AccentColor = "Cyan",
        [string[]]$TextPairs,
        [switch]$NoNewline,
        [switch]$clearLine
    )

    if($clearLine) {
        Write-HostClearLine -Message "" -Color "White" 
    }
    # Define default color for normal text
    $NormalColor = "White"

    # Ensure TextPairs is not empty
    if (-not $TextPairs -or $TextPairs.Count -eq 0) {
        return
    }

    # Loop through text pairs
    for ($i = 0; $i -lt $TextPairs.Count; $i += 2) {
        # Print normal text
        Write-Host -NoNewline $TextPairs[$i] -ForegroundColor $NormalColor

        # Print accented text if it exists, otherwise print the last normal text
        if ($i + 1 -lt $TextPairs.Count) {
            #Write-Host -NoNewline " "  # Space between normal and accented text
            Write-Host -NoNewline $TextPairs[$i + 1] -ForegroundColor $AccentColor
        }
    }
    # Add new line if requested, double negative logic
    if(-not $NoNewline) {
        Write-Host ""
    } 
}
