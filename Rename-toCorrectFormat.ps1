<#
.SYNOPSIS
    Converts the "x. Song Name.yyy" file format to "0x - Song Name.yyy" format. If there are more than 99 files,
        the target format is "00x - Song Name.yyy"

.DESCRIPTION
    This script was designed to use with "Commanders", like Unreal Commander.
    You can use it in a different ways, you have to pass in the working dir, and the file list
       in quotes. The file list should be one string, it will be split using one of the known 
       file formats. You should pass one type of files at a time.

.PARAMETER workingDir
	The name of the directory where your files are

.PARAMETER fileList
	List of file names that should be corrected
    
.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Geri
  Creation Date:  2024.12.06
  Purpose/Change: 2025.01.07 - Making ready for sharing

.EXAMPLE
    Rename-toCorrectFormat.ps1 -w "C:\myFolder\myMusic" -f "1. Loud Song.flac 2. Quiet Song.flac"
  
#>
#-------------------------------------------------------[Parameter Handling]-------------------------------------------------------
[CmdletBinding()] # For using the common parameters
    Param (
		[Parameter(Mandatory=$true)]
		[string]$workingDir,
		[string]$fileList
	)
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

function Remove-RepeatingPatterns {
    param (
        [string[]]$FileNames
    )

    if ($FileNames.Count -lt 2) { return $FileNames }

    $commonPattern = Get-CommonPattern $FileNames
    if ($commonPattern -ne '') {
        return $FileNames | ForEach-Object {
            $_ -replace [regex]::Escape($commonPattern), '' -replace '^\s+|\s+$', ''
        }
    }

    return $FileNames
}

function Get-CommonPattern {
    param ([string[]]$Strings)

    $first = $Strings[0]
    $commonPatterns = @()

    for ($length = $first.Length; $length -gt 3; $length--) { # Prevents too short patterns
        for ($i = 0; $i -le $first.Length - $length; $i++) {
            $substring = $first.Substring($i, $length)
            if ($Strings -notmatch [regex]::Escape($substring)) { continue }
            $commonPatterns += $substring.Trim()
        }
    }

    if ($commonPatterns.Count -gt 0) {
        return ($commonPatterns | Sort-Object Length -Descending | Select-Object -First 1)
    }
    
    return ''
}

$patterns = @(
    # The patterns to match. Originally I had one only, but I realized,
    #    that I have to use multiple patterns with exact matches, and explicitely
    #    defining what should be done in that case.
    # The 'gsign' is a temporary string, that will be replaced with a dash later, 
    #    this is the easiest way. You can add your own pattern, if this is not enough.
    @{ Pattern = '(^\d\d)( - )(.*)'; Replace = '$1 gsign $3' }, # this might look weird, but it is needed for to replace 'gsign' with a dash
    @{ Pattern = '(^\d\d)(, )(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d\d)(\. )(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d\d)(\.)(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d)(\. )(.*)'; Replace = '0$1 gsign $3' },
    @{ Pattern = '(^\d\d\d)(\. )(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d\d\d)( - )(.*)'; Replace = '$1 gsign $3' }, # this might look weird, but it is needed for to replace 'gsign' with a dash
    @{ Pattern = '(^\d\d)( )(\w.*)'; Replace = '$1 gsign $3' }, 
    @{ Pattern = '(^\d\d)(-)(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d)( - )(.*)'; Replace = '0$1 gsign $3' },
    @{ Pattern = '(^\d)( )(\w.*)'; Replace = '0$1 gsign $3' }
)

#--------------------------------------------------------------[Main]--------------------------------------------------------------
# Unreal Commander passes the parameters with a space at the end. We cut that off,
#   with a regex, so in case it is passed without it, it will not cause an issue.
# Write-Host "List first: '$fileList'" # This line might need for tshooting
$workingDir = $workingDir -replace ' ?$'
$fileList = $fileList -replace ' ?$'
$noMatch = 0 

# Write-Host "List: '$fileList'" # This line might need for tshooting
# We specify the possible file types.
# If you want to handle more file formats, just add here in the same manner
$fileFormats = @("flac", "dsd", "dsf", "mp3", "wav", "ape") 

# Initialize an array to hold the file list in an array
$fileListArray = @()
$usedFileExt = ''

# Loop through formats to split the file list
foreach ($fileFormat in $fileFormats) {
    if ($fileList -match "$fileFormat") {
        # Write-Output "The file '$fileList' is a $fileFormat file." # This line might need for tshooting
        $fileListArray = $fileList -split "(?<=$fileFormat) "
        $usedFileExt = $fileFormat
        $replacePatterns = @(
            " \(\d\d\d\d Remast.*\.$fileFormat"
            " \(Recorded.*\.$fileFormat"
            " \(Digit.*\.$fileFormat"
            " \(Resto.*\.$fileFormat"
            " \(Rema.*\.$fileFormat"
            " \(Arr.*\.$fileFormat"
            " \(Live.*\.$fileFormat"
        )
        break
    }
}


# "Default" case if no selector matched
if (-not $fileListArray) {
    Write-Output "The files '$fileList' does not match any known format."
    Start-Waiting
    exit
}

# Step 1: Initialize hashtable with oldName => newName pairs
$renameTable = @{}
$fileListArray | ForEach-Object { $renameTable[$_] = $_ }

# We need a helper array for looping
$keysForLoop = $renameTable.Keys | ForEach-Object { $_ } 

# Step 2: Detect and remove repeating patterns
$allNewNames = $renameTable.Values
# Stripping file extensons to avoid incorrect repetition text detection
$allNewNames = $allNewNames -replace "\.$usedFileExt$", ""
$repeatPattern = Get-CommonPattern $allNewNames
if ($repeatPattern -ne '') {
    $keysForLoop | ForEach-Object {
        $renameTable[$_] = $renameTable[$_] -replace [regex]::Escape($repeatPattern), '' -replace '^\s+|\s+$'. ''
    }
}

# We step through the files, and rename them
$keysForLoop | ForEach-Object { 
	# Write-Host "working on: $_ " # This line might need for tshooting
    $newName = $renameTable[$_]

    # Flag to check if a match was found
    $matched = $false

    # Loop through patterns and change when found in the file name. 
    # This steps make sure that the file name is starting like 01 - Name...
    foreach ($entry in $patterns) {
        if ($newName -match $entry.Pattern) {
            $matched = $true
            $newName = $newName -replace $entry.Pattern, $entry.Replace
            break 
        }
    }
    # Next we remove the (Remastered), (Recorde), and similar texts
    if ($newName -match ($replacePatterns -join "|")) {
        $newName = $newName -replace ($replacePatterns -join "|"), ".$usedFileExt"
    }    
    # The only thing left is to replace the characters I don't like...
    $newName = $newName -replace ' _ ', '; ' #[char]0xF025 # This is the "space-middledot-space" character
    $newName = $newName -replace ' -', ', ' # I do not like - in the file names, except after the number, so replacing it with a ,
    $newName = $newName -replace '- ', ', '
    $newName = $newName -replace '_', ' '
    $newName = $newName -replace '-', [char]0x2013 # This is for the dashes that stay, replacing them to a longer one.
    $newName = $newName -replace '  ', ' ' # Remowing the double spaces
    $newName = $newName -replace '\[', '('
    $newName = $newName -replace '\]', ')'
    $newName = $newName -replace "gsign", "-"
    # We put back the new name to the hash table
    $renameTable[$_] = $newName       

    # Handle no match case in the beginning of the filename
    if (-not $matched) {
        Write-Host -ForegroundColor Red -NoNewline "No matching digits found for file "
        Write-Host -ForegroundColor Yellow "$newName"
        $noMatch++
    }
}

# Step 4: Perform the actual renames
$renameTable.Keys | ForEach-Object {
    $oldPath = Join-Path -Path $workingDir -ChildPath $_
    $newPath = Join-Path -Path $workingDir -ChildPath $renameTable[$_]

    Rename-Item -LiteralPath $oldPath -NewName $newPath
    Write-Host "Renamed: $_ -> $($renameTable[$_])" # This print out does not make too much, unless there was something wrong...
}

Write-Host "Done"
if($noMatch -gt 0){ # There is a message that the user should read...
    Write-Host -ForegroundColor Red "`nThere were issues, please read the output.`nPress any key to exit..."
    Start-Waiting
}
