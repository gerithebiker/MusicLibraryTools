# Define paths
$AppDataPath = [System.Environment]::GetFolderPath("ApplicationData")
$tcBarFile = "$AppDataPath\Ghisler\default.bar"

$templateFile = "MLT_TC_Template.bar"
$backupBarFile = "$tcBarFile.bak"

function Get-isTCRunning {
    return (Get-Process -Name "TOTALCMD64" -ErrorAction SilentlyContinue) -or (Get-Process -Name "TOTALCMD" -ErrorAction SilentlyContinue)
}
while (Get-isTCRunning) {
    Write-Host "Total Commander is running, please close it to apply toolbar updates. Press any key to retry, or type in 'q' to exit!" -ForegroundColor Yellow
    $myKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")  # Wait for a key press
    if($myKey -eq 'q'){exit}
}

# Backup the original .bar file before modifications
if (Test-Path $tcBarFile) {
    Copy-Item -Path $tcBarFile -Destination $backupBarFile -Force
}

# Read the default.bar content
$tcBarContent = Get-Content $tcBarFile

# Extract the current Buttoncount value
$buttonCountLine = $tcBarContent | Select-String "^Buttoncount\s*=\s*(\d+)"
if ($buttonCountLine) {
    $currentButtonCount = [int]($buttonCountLine.Matches.Groups[1].Value)
} else {
    Write-Host "Error: Could not find Buttoncount in $tcBarFile" -ForegroundColor Red
    exit 1
}

# Read the template content
$templateContent = Get-Content $templateFile

# Adjust the numbering in the template
$updatedTemplate = @()
$counter = $currentButtonCount + 1

foreach ($line in $templateContent) {
    if ($line -match "^(button|cmd|param)(\d+)(=.*)$") {
        # Extract type (button/cmd/param) and update the index
        $updatedTemplate += "$($matches[1])$counter$($matches[3])"
        if ($matches[1] -eq "param") { $counter++ }  # Increase only on button lines
    } else {
        $updatedTemplate += $line  # Keep other lines unchanged
    }
}

# Update the Buttoncount value in default.bar
$tcBarContent = $tcBarContent -replace "^Buttoncount\s*=\s*\d+", "Buttoncount=$($counter - 1)"

# Append the updated template content
$tcBarContent += $updatedTemplate

# Write the updated content back to default.bar
$tcBarContent | Set-Content $tcBarFile

Write-Host "TC button bar successfully updated! New Buttoncount: $($counter - 1)" -ForegroundColor Green
