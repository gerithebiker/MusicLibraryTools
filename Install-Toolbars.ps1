# Configuration
$buttonConfigFile = ".\buttons.ini"  # Path to the button configuration file
$tcBarFile = "$env:APPDATA\GHISLER\default.bar"  # Total Commander toolbar file
$ucIniFile = "$env:APPDATA\Unreal Commander\uc.ini"  # Unreal Commander INI file

# Function to parse button settings
function ConvertFrom-ButtonConfig {
    param ([string]$filePath)
    $buttons = @()
    $currentButton = @{}

    foreach ($line in Get-Content $filePath) {
        if ($line -match "=") {
            $key, $value = $line -split "=", 2
            $currentButton[$key.Trim()] = $value.Trim()
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
    param ([array]$buttons)

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
    param ([array]$buttons)

    # Check if Unreal Commander is running
    # This has to be updated to be a bit more sophisticated
    if ((Get-Process -Name "uc64" -ErrorAction SilentlyContinue) -or (Get-Process -Name "uc" -ErrorAction SilentlyContinue)) {
        Write-Warning "Unreal Commander is running. Please close it to apply toolbar updates."
        pause
    }

    if (-not (Test-Path $ucIniFile)) {
        Write-Host "Creating new Unreal Commander INI file."
        New-Item -Path $ucIniFile -ItemType File -Force
    }

    # Backup original file
    Copy-Item $ucIniFile "$ucIniFile.bak"

    $ucConfig = if (Test-Path $ucIniFile) { Get-Content $ucIniFile -Raw } else { "" }

    if ($ucConfig -notmatch "\[ToolBar\]") {
        $ucConfig += "`n[ToolBar]`n"
    }

    foreach ($button in $buttons) {
        $ucConfig += "$($button.Command),$($button.Tooltip),$($button.Icon)`n"
    }

    $ucConfig | Set-Content -Path $ucIniFile -Encoding UTF8
    Write-Host "Unreal Commander toolbar updated successfully!"
}

# Main Script
Write-Host "Do you want to install toolbars for Total Commander (TC), Unreal Commander (UC), or both? (Enter: TC/UC/both)"
$userChoice = Read-Host "Your choice"

if (-not (Test-Path $buttonConfigFile)) {
    Write-Error "Button configuration file not found: $buttonConfigFile"
    exit
}

# Parse buttons
$buttons = ConvertFrom-ButtonConfig -filePath $buttonConfigFile

switch ($userChoice.ToLower()) {
    "tc" {
        Update-TC -buttons $buttons
    }
    "uc" {
        Update-UC -buttons $buttons
    }
    "both" {
        Update-TC -buttons $buttons
        Update-UC -buttons $buttons
    }
    default {
        Write-Error "Invalid choice. Please enter 'TC', 'UC', or 'both'."
    }
}

Write-Host "Toolbar installation completed!"
