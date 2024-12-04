# This script was designed to use with "Commanders", like Unreal Commander.
# You can use it in a different way, you have to just pass in the working dir, and the life list
#       in quotes. The file list should be one string, it will be split using one of the known 
#       file formats.

[CmdletBinding()] # For using the common parameters
    Param (
		[Parameter(Mandatory=$true)]
		[string]$workingDir,
		[string]$fileList
	)

# Unreal Commander passes the parameters with a space at the end. We cut that off,
#   with a regex, so in case it is passed without it, it will not cause an issue.
$workingDir = $workingDir -replace ' ?$'
$fileList = $fileList -replace ' ?$'
$noMatch = 0 

# Write-Host "List: '$fileList'" # This line might need for tshooting
# We specify the possible file types.
# If you want to handle more file formats, just add here in the same manner
$fileFormats = @("flac", "dsd", "dsf", "mp3", "wav", "ape") 

# Initialize an array to hold the file list in an array
$fileListArray = @()

# Loop through formats to split the file list
foreach ($fileFormat in $fileFormats) {
    if ($fileList -match "$fileFormat$") {
        Write-Output "The file '$fileList' is a $fileFormat file."
        $fileListArray = $fileList -split "(?<=$fileFormat) "
        break
    }
}

# "Default" case if no selector matched
if (-not $fileListArray) {
    Write-Output "The file '$fileList' does not match any known format."
    Start-Sleep -s 20
}

#$fileListArray | ForEach-Object { Write-Host $_ } # This line was used only during development

# We step through the files, and rename them
$fileListArray | ForEach-Object { 
	Write-Host "working on: $_ "
	$newName = $_ -replace ' -', ', ' # I do not like - in the file names, except after the number, so replacing it with a ,
	$newName = $newName -replace '-', [char]0x2013 # This is for the dashes that stay, replacing them to a longer one.
	$newName = $newName -replace '  ', ' ' # Remowing the double spaces
    # Check the input against regex patterns
    if ($newName -match "\d\d\. ?") {
        $newName = $newName -replace '(\d\d?)(. ?)(.*)', '$1 - $3' # This will replace third character with a possible space after.
    } elseif ($newName -match "\d\. ?") {
        $newName = $newName -replace '(\d?)(. ?)(.*)', '0$1 - $3' # This will replace second character with a possible space after and put a 0 at the beginning...
    } else {
        Write-Host -ForegroundColor Red -BackgroundColor Blue -NoNewline "No matching digits found for file "
        Write-Host -ForegroundColor Yellow -BackgroundColor Blue "$_"
        $noMatch++
    }
	# $newName = $newName -replace '(\d\d?)(. ?)(.*)', '$1 - $3' # This will replace third character with a possible space after.
	$newName = Join-Path -Path $workingDir -ChildPath $newName
	$oldName = Join-Path -Path $workingDir -ChildPath $_
	
	Rename-Item -LiteralPath $oldName -NewName $newName -Force
    # Next 2 lines are for tshooting/development
	# $fullNewName = $workingDir$newName
	# Write-Host "NN: $newName --- $oldName"
}

Write-Host "Done"
if($noMatch -gt 0){ # There is a message that the user should read...
    Write-Host -ForegroundColor Red -BackgroundColor Blue "`nThere were issues, please read the output.`nPress any key to exit..."
    while ($true) {
        if ($Host.UI.RawUI.KeyAvailable) {
            break
        }
    }
}

# For tshooting, or if you just want to see the messages, uncomment the following line
# 