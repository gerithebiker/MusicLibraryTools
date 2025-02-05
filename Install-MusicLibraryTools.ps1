<#
.SYNOPSIS
Installs MusicLibraryTools by downloading scripts, configuring files, and validating the environment.

.DESCRIPTION
This script downloads the MusicLibraryTools repository, creates necessary configuration files,
and ensures that PowerShell 5.x is installed.

.AUTHOR
Your Name
#>

#-------------------------------------------------------[Declarations]-------------------------------------------------------
$installPS5Message = @"
To install PowerShell 5.x:
1. Download the Windows Management Framework 5.1 from the official Microsoft website:
   https://www.microsoft.com/en-us/download/details.aspx?id=54616
2. Follow the installation instructions provided on the download page.
3. After installation, restart your system if prompted.

Note: If you're using an older version of Windows (e.g., Windows 7/8), ensure your system meets the requirements listed on the download page.
"@


# Define paths
$MusicLibraryToolsPath = "$env:APPDATA\MusicLibraryTools"
$RepoURL = "https://github.com/gerithebiker/MusicLibraryTools"
#$MusicLibraryToolsPath = "$MusicLibraryToolsPath\repo"
$LibraryPath = "$MusicLibraryToolsPath\MusicLibraryTools.Library.psm1"
$IniFilePath = "$MusicLibraryToolsPath\UnrealCommanderToolbarButtons.ini"
$TempIniFilePath = "$MusicLibraryToolsPath\UnrealCommanderToolbarButtons.temp.ini"
$ConfigFilePath = "$MusicLibraryToolsPath\mTools.ini"

#-------------------------------------------------------[PowerShell Checking]-------------------------------------------------
# Ensure PowerShell 5.x is installed
$PS5Path = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
if (Test-Path -Path $PS5Path) {
    # Check the version of the executable
    $PS5Version = & $PS5Path  -NoProfile -Command { $PSVersionTable.PSVersion.Major } 
    #$PS5Version = $PS5Version.Trim()

    if ($PS5Version -eq 5) {
        Write-Host "`nPowerShell 5.x is installed and available at $PS5Path."
    } else {
        Write-Host -NoNewline "The PowerShell executable at '" 
        Write-Host -NoNewline $PS5Path -ForegroundColor Red 
        Write-Host "' is not version 5. Detected version: $PS5Version."
        Write-Host $installPS5Message
        exit 1
    }
} else {
    Write-Host -NoNewline "`nPowerShell 5.x executable not found at '" 
    Write-Host -NoNewline $PS5Path -ForegroundColor Red 
    Write-Host "'. Please ensure it is installed."
    Write-Host $installPS5Message
    exit 1
}


#-------------------------------------------------------[User Approval]-------------------------------------------------------
Write-Host "`nWelcome to the MusicLibraryTools installation script!" -ForegroundColor Green
if(-not (Test-Path -Path $MusicLibraryToolsPath)) {
    Write-Host -NoNewline "This script will create the '"
    Write-Host -NoNewline $MusicLibraryToolsPath -ForegroundColor Red
    Write-Host "' directory."
} else {
    Write-Host "The MusicLibraryTools folder '$MusicLibraryToolsPath' already exists." -ForegroundColor Green
}

Write-Host "The MusicLibraryTools repository will be downloaded and configured." -ForegroundColor Green
Write-Host -NoNewline "Do you want to continue? Type exactly '"
Write-Host -NoNewline -ForegroundColor Red "Yes"
Write-Host -NoNewline "' to proceed: "
$UserInput = Read-Host 

if ($UserInput -ceq "Yes") {
    Write-Host "Installation requested. Directory '$MusicLibraryToolsPath' will be used." -ForegroundColor Green
} else {
    Write-Host "Installation aborted by the user." -ForegroundColor Red
    exit 0
}

# Step 1: Ensure the MusicLibraryTools folder exists
if (-not (Test-Path -Path $MusicLibraryToolsPath)) {
    Write-Host "Creating MusicLibraryTools directory at $MusicLibraryToolsPath..."
    New-Item -ItemType Directory -Path $MusicLibraryToolsPath | Out-Null
}

# Step 2: Download or update the repository
if (Test-Path "$MusicLibraryToolsPath\.git") {
    Write-Host "Updating existing MusicLibraryTools repository..."
    Push-Location $MusicLibraryToolsPath
    git pull
    Pop-Location
} else {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host "Cloning MusicLibraryTools repository..."
        git clone $RepoURL $MusicLibraryToolsPath
    } else {
        Write-Host "Git is not installed. Downloading repository as ZIP..."
        $ZipPath = "$MusicLibraryToolsPath\repo.zip"
        Invoke-WebRequest -Uri "$RepoURL/archive/main.zip" -OutFile $ZipPath
        Expand-Archive -Path $ZipPath -DestinationPath $MusicLibraryToolsPath
        Remove-Item -Path $ZipPath
        Move-Item -Path "$MusicLibraryToolsPath\MusicLibraryTools-main\*" -Destination $MusicLibraryToolsPath -Force
        Remove-Item -Path "$MusicLibraryToolsPath\MusicLibraryTools-main" -Recurse -Force
    }
}

# Step 3: Import the library module
if (Test-Path -Path $LibraryPath) {
    Import-Module -Name $LibraryPath -Force
    Write-Host "MusicLibraryTools library module imported successfully."
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
    if(Test-Path $TempIniFilePath){Remove-Item -Path $TempIniFilePath -Force}
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
