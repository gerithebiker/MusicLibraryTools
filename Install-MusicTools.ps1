<#
.SYNOPSIS
Installs MusicTools by downloading scripts, configuring files, and validating the environment.

.DESCRIPTION
This script downloads the MusicTools repository, creates necessary configuration files,
and ensures that PowerShell 5.x is installed.

.AUTHOR
Your Name
#>


# Define paths
$MusicToolsPath = "$env:USERPROFILE\MusicTools"
$RepoURL = "https://github.com/gerithebiker/MusicTools"
#$MusicToolsPath = "$MusicToolsPath\repo"
$LibraryPath = "$MusicToolsPath\MusicTools.Library.psm1"
$IniFilePath = "$MusicToolsPath\UnrealCommanderToolbarButtons.ini"
$TempIniFilePath = "$MusicToolsPath\UnrealCommanderToolbarButtons.temp.ini"
$ConfigFilePath = "$MusicToolsPath\SourceDestinationPairs.txt"

#-------------------------------------------------------[User Approval]-------------------------------------------------------

$UserInput = Read-Host "This script will download and configure MusicTools in '$MusicToolsPath' directory. Do you want to continue? Type 'Yes' to proceed"

if ($UserInput -ceq "Yes") {
    Write-Host "Installation requested." -ForegroundColor Green
} else {
    Write-Host "Installation aborted by the user." -ForegroundColor Red
    exit 0
}

# Ensure PowerShell 5.x is installed
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Write-Host "PowerShell 5.x detected."
} else {
    Write-Warning "PowerShell 5.x is required. Detected version: $($PSVersionTable.PSVersion)."
    Write-Host @"
To install PowerShell 5.x:
1. Download the Windows Management Framework 5.1 from the official Microsoft website:
   https://www.microsoft.com/en-us/download/details.aspx?id=54616
2. Follow the installation instructions provided on the download page.
3. After installation, restart your system if prompted.

Note: If you're using an older version of Windows (e.g., Windows 7/8), ensure your system meets the requirements listed on the download page.
"@
    exit 1
}

# Step 1: Ensure the MusicTools folder exists
if (-not (Test-Path -Path $MusicToolsPath)) {
    Write-Host "Creating MusicTools directory at $MusicToolsPath..."
    New-Item -ItemType Directory -Path $MusicToolsPath | Out-Null
}

# Step 2: Download or update the repository
if (Test-Path "$MusicToolsPath\.git") {
    Write-Host "Updating existing MusicTools repository..."
    Push-Location $MusicToolsPath
    git pull
    Pop-Location
} else {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host "Cloning MusicTools repository..."
        git clone $RepoURL $MusicToolsPath
    } else {
        Write-Host "Git is not installed. Downloading repository as ZIP..."
        $ZipPath = "$MusicToolsPath\repo.zip"
        Invoke-WebRequest -Uri "$RepoURL/archive/main.zip" -OutFile $ZipPath
        Expand-Archive -Path $ZipPath -DestinationPath $MusicToolsPath
        Remove-Item -Path $ZipPath
        Move-Item -Path "$MusicToolsPath\MusicTools-main\*" -Destination $MusicToolsPath -Force
        Remove-Item -Path "$MusicToolsPath\MusicTools-main" -Recurse -Force
    }
}

# Step 3: Import the library module
if (Test-Path -Path $LibraryPath) {
    Import-Module -Name $LibraryPath -Force
    Write-Host "MusicTools library module imported successfully."
} else {
    Write-Warning "Library module not found at '$LibraryPath'. Ensure the repository includes it."
    exit 1
}

# Step 4: Handle Unreal Commander Toolbar Buttons ini file
if (-not (Test-Path -Path $IniFilePath)) {
    Write-Host "Creating Unreal Commander Toolbar Buttons file..."
    Update-UnrealCommanderToolbarButtons -IniFilePath $IniFilePath -TempIniFilePath $TempIniFilePath
    Write-Host "INI file created and updated successfully."
} else {
    Write-Host "INI file already exists. Preserving user-defined settings."
    Remove-Item -Path $TempIniFilePath
}

# Step 5: Set up the config file using Set-ConfigFile
if (-not (Test-Path -Path $ConfigFilePath)) {
    Write-Host "Setting up the configuration file..."
    Set-ConfigFile -ConfigFilePath $ConfigFilePath
    Write-Host "Configuration file set up successfully."
} else {
    Write-Host "Configuration file already exists. Preserving user-defined settings."
}

Write-Host "Deployment completed successfully!"
