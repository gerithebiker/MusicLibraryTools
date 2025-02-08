# Configuration
$buttonConfigFile = ".\MLT_UC_Buttons.ini"  # Path to the button configuration file
$tcBarFile = "$env:APPDATA\GHISLER\default.bar"  # Total Commander toolbar file
$ucBarFile = "$env:APPDATA\Unreal Commander\uncom.bar"  # Unreal Commander bar file

# Function to parse button settings
function ConvertFrom-ButtonConfig {
    param ([string]$filePath)
    $buttons = @()
    $currentButton = @{}

    foreach ($line in Get-Content $filePath) {
        if ($line -match "=") {
            $key, $value = $line -split "=", 2
            $currentButton[$key.Trim()] = $value.Trim() -replace '\{\{appdata\}\}', $env:APPDATA
        } elseif ($line.Trim() -eq "") {
            if ($currentButton.Count -gt 0) {
                $buttons += [PSCustomObject]$currentButton
                $currentButton = @{}
            }
        }
    }

    if ($currentButton.Count -gt 0) {
        $buttons += [PSCustomObject]$currentButton
    }

    return $buttons
}

# Function to update Total Commander toolbar
function Update-TC {
    param (
        [array]$buttons,
        [string]$tcBarFile
    )

    # Check if Total Commander is running
    # This has to be updated to be a bit more sophisticated
    if ((Get-Process -Name "TOTALCMD64" -ErrorAction SilentlyContinue) -or (Get-Process -Name "TOTALCMD" -ErrorAction SilentlyContinue)) {
        Write-Warning "Total Commander is running. Please close it to apply toolbar updates."
        pause
    }

    if (-not (Test-Path $tcBarFile)) {
        Write-Host "Creating new Total Commander toolbar file."
        New-Item -Path $tcBarFile -ItemType File -Force
    }

    # Backup original file
    Copy-Item $tcBarFile "$tcBarFile.bak"

    foreach ($button in $buttons) {
        Add-Content -Path $tcBarFile -Value @"
$($button.Command)
$($button.StartPath)
$($button.Tooltip)
$($button.Icon)
"@
    }
    Write-Host "Total Commander toolbar updated successfully!"
}

# Function to update Unreal Commander toolbar
function Update-UC {
    param (
        [array]$buttons,          # Array of hashtables with keys: Command, Params, Tooltip, Icon, Directory, Hotkey, AsAdmin
        [string]$ucBarFile        # Path to the Unreal Commander INI file
    )
    $buttons = @(
        @{  
            Command = "powershell.exe"; 
            Params = "script.ps1"; 
            Tooltip = "Run Script"; 
            Icon = "%windir%\\icon.dll\\i=116"; 
            Directory = "C:\\Scripts"; 
            Hotkey = 0; 
            AsAdmin = $false 
        },
        @{ Command = "explorer.exe"; Params = ""; Tooltip = "Open Explorer"; Icon = "%windir%\\icon.dll\\i=121"; Directory = "C:\\"; Hotkey = 0; AsAdmin = $false }
    )
    
    # Check if Unreal Commander is running
    if (Get-Process -Name "uc64", "uc" -ErrorAction SilentlyContinue) {
        Write-Warning "Unreal Commander is running. Please close it to apply toolbar updates."
        pause
        return
    }

    if (-not (Test-Path $ucBarFile)) {
        Write-Host "Creating new Unreal Commander INI file."
        New-Item -Path $ucBarFile -ItemType File -Force
    }

    # Backup original file
    Copy-Item $ucBarFile "$ucBarFile.bak" -Force

    # Read existing INI file content
    $ucConfig = Get-Content $ucBarFile -Raw

    # Ensure [Buttons] section exists
    if ($ucConfig -notmatch '\[Buttons\]') {
        $ucConfig += "`n[Buttons]`n"
    }

    # Parse INI into hashtable for easy manipulation
    $iniContent = @{}
    $currentSection = ""
    foreach ($line in $ucConfig -split "`n") {
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $matches[1]
            $iniContent[$currentSection] = @{}
        } elseif ($line -match '^(.*?)=(.*)$' -and $currentSection) {
            $iniContent[$currentSection][$matches[1].Trim()] = $matches[2].Trim()
        }
    }

    # Update Buttons Section
    $buttonCount = $buttons.Count
    $iniContent['Buttons']['Buttoncount'] = $buttonCount

    for ($i = 0; $i -lt $buttonCount; $i++) {
        $button = $buttons[$i]
        $iniContent['Buttons']["cmd$i"] = $button.Command
        $iniContent['Buttons']["prm$i"] = $button.Params
        $iniContent['Buttons']["dir$i"] = $button.Directory
        $iniContent['Buttons']["hint$i"] = $button.Tooltip
        $iniContent['Buttons']["hotkey$i"] = $button.Hotkey
        $iniContent['Buttons']["AsAdmin$i"] = if ($button.AsAdmin) {1} else {0}
        $iniContent['Buttons']["btn$i"] = $button.Icon
    }

    # Rebuild INI content
    $newContent = ""
    foreach ($section in $iniContent.Keys) {
        $newContent += "[$section]`n"
        foreach ($key in $iniContent[$section].Keys) {
            $newContent += "$key=$($iniContent[$section][$key])`n"
        }
        $newContent += "`n"
    }

    # Save changes
    $newContent | Set-Content -Path $ucBarFile -Encoding UTF8
    Write-Host "Unreal Commander toolbar updated successfully!"
}


# Main Script
Write-Host "Do you want to install toolbars for Total Commander (TC), Unreal Commander (UC), or both? (Enter: TC/UC/both)"
$userChoice = "TC" #Read-Host "Your choice"

if (-not (Test-Path $buttonConfigFile)) {
    Write-Error "Button configuration file not found: $buttonConfigFile"
    exit
}

# Parse buttons
$buttons = ConvertFrom-ButtonConfig -filePath $buttonConfigFile

switch ($userChoice.ToLower()) {
    "tc" {
        Update-TC -buttons $buttons -tcBarFile $tcBarFile
    }
    "uc" {
        Update-UC -buttons $buttons -ucBarFile $ucBarFile
    }
    "both" {
        Update-TC -buttons $buttons -tcBarFile $tcBarFile
        Update-UC -buttons $buttons -ucBarFile $ucBarFile
    }
    default {
        Write-Error "Invalid choice. Please enter 'TC', 'UC', or 'both'."
    }
}

Write-Host "Toolbar installation completed!"
