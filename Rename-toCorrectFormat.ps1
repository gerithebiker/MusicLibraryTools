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


  We intentionally use Unicode FULLWIDTH COLON '：'(U+FF1A) instead of ASCII ':'
  because ':' is illegal in Windows filenames.

.EXAMPLE
    Rename-toCorrectFormat.ps1 -w "C:\myFolder\myMusic" -f "1. Loud Song.flac 2. Quiet Song.flac"
  
#>
#region ParameterHandling
#-------------------------------------------------------[Parameter Handling]-------------------------------------------------------
[CmdletBinding()] # For using the common parameters
    Param (
		[Parameter(Mandatory=$true)]
		[string]$workingDir,
		[string]$fileList
	)
#endregion Parameterhandling
#---------------------------------------------[Initializing Standard Funcrions, variables]------------------------------------------
#region initHandling
$iniPath = "$env:APPDATA\MusicLibraryTools\mTools.ini"
$iniPath = "$env:USERPROFILE\Documents\GitHub\MusicLibraryTools\mTools.ini"

$libraryPath = (
    (Get-Content -LiteralPath $iniPath -TotalCount 1) -split '=',2
)[1].Trim('"')
$libraryPath = [Environment]::ExpandEnvironmentVariables($libraryPath)
Import-Module $libraryPath -Force -ErrorAction Stop
#endregion initHandling

#------------------------------------------------------------[Functions]------------------------------------------------------------
#region FunctionDeclarations
function Remove-DuplicateTrackTitlePattern {
    param(
        [string]$Name,
        [string[]]$FileFormats
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        # I am not sure if this will ever run... After all, first you select a list of files... 
        # In case of a file is spaces only:
        Write-Host "The file $Name does not seem to me correct, pls check it!"
        Start-Waiting
        return $Name
    }

    $ext = ""
    $base = $Name

    foreach ($format in $FileFormats) {
        $candidate = ".$format"

        if ($Name.EndsWith($candidate, [System.StringComparison]::OrdinalIgnoreCase)) {
            $ext = $Name.Substring($Name.Length - $candidate.Length)
            $base = $Name.Substring(0, $Name.Length - $candidate.Length)
            break
        }
    }

    $pattern = '^(?<firstPrefix>\d{1,3}\s*[-.]\s*)(?<firstTitle>.+?)(?<secondPrefix>\d{1,3}\s*[-.]\s*)(?<secondTitle>.+)$'

    if ($base -match $pattern) {
        $firstTitle  = $matches.firstTitle.Trim()
        $secondTitle = $matches.secondTitle.Trim()

        if ($firstTitle.ToLowerInvariant() -eq $secondTitle.ToLowerInvariant()) {
            return "$($matches.firstPrefix)$firstTitle$ext"
        }
    }

    return $Name
}

function Convert-FromAllCaps {
    param(
        [string]$Text
    )

    # Track number prefix leválasztása:
    # "01 - THE GIRL FROM IPANEMA"
    # prefix = "01 - "
    # Text   = "THE GIRL FROM IPANEMA"
    if ($Text -match '^(\d{1,4}\s*-\s*)(.+)$') {
        $prefix = $matches[1]
        $Text   = $matches[2].Trim()
    }
    else {
        $prefix = ''
        $Text   = $Text.Trim()
    }

    $smallWords = @(
        'a', 'an', 'and', 'as', 'at',
        'by',
        'for', 'from',
        'in', 'into', 'is',
        'of', 'off', 'on', 'onto', 'or',
        'the', 'to',
        'up',
        'via',
        'with',
        'vs', 'vs.'
    )

    $ti = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo

    # Alap Title Case
    $result = $ti.ToTitleCase($Text.ToLowerInvariant())

    # Szavak feldolgozása
    $words = $result -split '\s+'

    for ($i = 0; $i -lt $words.Count; $i++) {

        # Végén levő írásjelek különválasztása
        if ($words[$i] -match '^(.+?)([.,:;!?)]*)$') {

            $word  = $matches[1]
            $punct = $matches[2]

            # Kis szavak csak a cím BELSEJÉBEN legyenek kisbetűsek.
            # Az első és az utolsó szó mindig Title Case marad.
            if (
                ($i -ne 0) -and
                ($i -ne ($words.Count - 1)) -and
                ($smallWords -contains $word.ToLowerInvariant())
            ) {
                $word = $word.ToLowerInvariant()
            }

            $words[$i] = $word + $punct
        }
    }

    $result = $words -join ' '

    # Római számok javítása
    $romanMap = @{
        'Ii'     = 'II'
        'Iii'    = 'III'
        'Iv'     = 'IV'
        'Vi'     = 'VI'
        'Vii'    = 'VII'
        'Viii'   = 'VIII'
        'Ix'     = 'IX'

        'Xi'     = 'XI'
        'Xii'    = 'XII'
        'Xiii'   = 'XIII'
        'Xiv'    = 'XIV'
        'Xv'     = 'XV'
        'Xvi'    = 'XVI'
        'Xvii'   = 'XVII'
        'Xviii'  = 'XVIII'
        'Xix'    = 'XIX'

        'Xx'     = 'XX'
        'Xxi'    = 'XXI'
        'Xxii'   = 'XXII'
        'Xxiii'  = 'XXIII'
        'Xxiv'   = 'XXIV'
        'Xxv'    = 'XXV'
        'Xxvi'   = 'XXVI'
        'Xxvii'  = 'XXVII'
        'Xxviii' = 'XXVIII'
        'Xxix'   = 'XXIX'

        'Xxx'    = 'XXX'
    }

    foreach ($key in $romanMap.Keys) {
        $result = $result -replace "\b$key\b", $romanMap[$key]
    }

    # Sorszámok javítása
    $result = $result -replace '(\d+)St\b', '$1st'
    $result = $result -replace '(\d+)Nd\b', '$1nd'
    $result = $result -replace '(\d+)Rd\b', '$1rd'
    $result = $result -replace '(\d+)Th\b', '$1th'

    return "$prefix$result"
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

function Split-TrackBaseName {
    param(
        [string]$BaseName
    )

    # Splits only the leading track marker from the title body.
    # Examples:
    #   01 - BEETHOVEN： MISSA SOLEMNIS -> Track=01, Title=BEETHOVEN： MISSA SOLEMNIS
    #   1. Some Song                     -> Track=1,  Title=Some Song
    #   A Some Song                      -> Track=A,  Title=Some Song
    if ($BaseName -match '^\s*(?<track>\d{1,3}|[A-D])\s*(?:[-,.]\s*)?(?<title>.+?)\s*$') {
        return [PSCustomObject]@{
            HasTrack = $true
            Track    = $matches['track']
            Title    = $matches['title']
        }
    }

    return [PSCustomObject]@{
        HasTrack = $false
        Track    = ''
        Title    = $BaseName
    }
}

function Join-TrackBaseName {
    param(
        [Parameter(Mandatory=$true)]$Parts
    )

    $title = $Parts.Title -replace '^\s+|\s+$', ''
    $title = $title -replace '^[\s:：;\-–—]+', ''
    $title = $title -replace '[\s:：;\-–—]+$', ''

    if ($Parts.HasTrack) {
        return "$($Parts.Track) - $title"
    }

    return $title
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


function Get-LeadingSeparatedPrefixInfo {
    param(
        [string]$Title
    )

    # Finds an explicit leading artist/composer prefix.
    # Examples:
    #   BEETHOVEN： SYMPHONY NO.9  -> Prefix=BEETHOVEN, Rest=SYMPHONY NO.9
    #   Miles Davis: So What       -> Prefix=Miles Davis, Rest=So What
    #   Genesis - Entangled        -> Prefix=Genesis, Rest=Entangled
    # Hyphen/dash only counts as a separator when it has spaces around it.

    $patterns = @(
        '^\s*(?<prefix>.+?)\s*(?<sep>[：:;|])\s*(?<rest>.+?)\s*$',
        '^\s*(?<prefix>.+?)\s+(?<sep>[-–—])\s+(?<rest>.+?)\s*$'
    )

    foreach ($pattern in $patterns) {
        if ($Title -match $pattern) {
            $sep = $matches['sep']
            if ($sep -in @('：', ':')) { $sep = ':' }
            elseif ($sep -in @('-', '–', '—')) { $sep = '-' }

            return [PSCustomObject]@{
                PrefixText = $matches['prefix'].Trim()
                PrefixNorm = $matches['prefix'].Trim().ToLowerInvariant()
                SepNorm    = $sep
                Rest       = $matches['rest'].Trim()
            }
        }
    }

    return $null
}

function Get-SharedLeadingSeparatedPrefix {
    param(
        [string[]]$Titles
    )

    $cleanTitles = @($Titles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($cleanTitles.Count -lt 2) { return $null }

    $infos = @()
    foreach ($title in $cleanTitles) {
        $info = Get-LeadingSeparatedPrefixInfo -Title $title
        if ($null -eq $info) { return $null }
        $infos += $info
    }

    $first = $infos[0]
    if ([string]::IsNullOrWhiteSpace($first.PrefixText)) { return $null }

    foreach ($info in $infos) {
        if ($info.PrefixNorm -ne $first.PrefixNorm -or $info.SepNorm -ne $first.SepNorm) {
            return $null
        }
    }

    return [PSCustomObject]@{
        PrefixNorm = $first.PrefixNorm
        SepNorm    = $first.SepNorm
    }
}

function Remove-SharedLeadingSeparatedPrefix {
    param(
        [string]$Title,
        [Parameter(Mandatory=$true)]$SharedPrefix
    )

    $info = Get-LeadingSeparatedPrefixInfo -Title $Title
    if ($null -ne $info -and $info.PrefixNorm -eq $SharedPrefix.PrefixNorm -and $info.SepNorm -eq $SharedPrefix.SepNorm) {
        return $info.Rest.Trim()
    }

    return $Title
}

#endregion FunctionDeclarations

#-----------------------------------------------------------["Constants"]-----------------------------------------------------------
#region Constants
# We specify the possible file types.
# If you want to handle more file formats, just add here in the same manner
$fileFormats = @("flac", "dsd", "dsf", "mp3", "wav", "ape") 

$patterns = @(
    # The patterns to match. Originally I had one only, but I realized,
    #    that I have to use multiple patterns with exact matches, and explicitely
    #    defining what should be done in that case.
    # The 'gsign' is a temporary string, that will be replaced with a dash later, 
    #    this is the easiest way. You can add your own pattern, if this is not enough.
    @{ Pattern = '^0?(\d+)-0?(\d{1,3})(\s*-\s*)(.*)'; Replace = '$1$2 gsign $4' }, # this might look weird, but it is needed for to replace 'gsign' with a dash
    @{ Pattern = '(^\d\d)( - )(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d\d)(, )(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d\d)(\. )(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d\d)(\.)(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d)(\. )(.*)'; Replace = '0$1 gsign $3' },
    @{ Pattern = '(^\d\d\d)(\. )(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d\d\d)( - )(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d\d)( )(\w.*)'; Replace = '$1 gsign $3' }, 
    @{ Pattern = '(^\d\d)(-)(.*)'; Replace = '$1 gsign $3' },
    @{ Pattern = '(^\d)( - )(.*)'; Replace = '0$1 gsign $3' },
    @{ Pattern = '(^\d)( )(\w.*)'; Replace = '0$1 gsign $3' }
)

$PrettyColon     = [char]0xFF1A   # ：
#endregion Constants
#--------------------------------------------------------------[Main]---------------------------------------------------------------
#region Main
# Unreal Commander passes the parameters with a space at the end. We cut that off,
#   with a regex, so in case it is passed without it, it will not cause an issue.
# Write-Host "List first: '$fileList'" # This line might need for tshooting
$workingDir = $workingDir -replace ' ?$'
$fileList = $fileList -replace ' ?$'
$noMatch = 0 

# Write-Host "List: '$fileList'" # This line might need for tshooting

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
            " \(\d{4} Remast.*$",
            " \(Recorded.*$",
            " \(Digit.*$",
            " \(Resto.*$",
            " \(Rema.*$",
            " \(Arr.*$",
            " \(Live.*$"
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

# Initialize hashtable with oldName => newName pairs
$renameTable = @{}
$fileListArray | ForEach-Object { $renameTable[$_] = $_ }

# We need a helper array for looping
$keysForLoop = $renameTable.Keys | ForEach-Object { $_ } 

# Next we remove the (Remastered), (Recorde), and similar texts, those are really unnecessary in a file name
$keysForLoop | ForEach-Object {
    $newName = $renameTable[$_]

    # Now we gonna remove the repeated patterns inside a single file name
    $newName = Remove-DuplicateTrackTitlePattern $newName $fileFormats

    # Here we use the previously defined patterns
    foreach ($pattern in $replacePatterns) {
        $newName = $newName -replace $pattern, ""
    }

    # The previous foreach removes the extension, we put it back if missing
    # There could be cases (for example missing pattern) when the extension is not removed, hence the if structure
    if (-not $newName.EndsWith(".$usedFileExt")) {
        $newName = "$newName.$usedFileExt"
    }

    # Write back the result to the hash table
    $renameTable[$_] = $newName
}

# Detect and remove a shared leading separated prefix.
# This intentionally does NOT remove the longest common text.
# It removes only an explicit shared prefix segment, for example:
#   BEETHOVEN： SYMPHONY NO.9 1st mov.  -> SYMPHONY NO.9 1st mov.
#   Genesis - Dance on a Volcano        -> Dance on a Volcano
# It will NOT remove "SYMPHONY" just because every title starts with that word.
$sharedPrefix = $null

# Detect and remove a shared leading separated prefix.
# Example:
#   BEETHOVEN： SYMPHONY NO.9 1st mov. -> SYMPHONY NO.9 1st mov.

# if ($renameTable.Count -gt 1) {
#     $prefixCounts = @{}

#     # First pass: collect leading separated prefixes
#     $keysForLoop | ForEach-Object {
#         $currentName = $renameTable[$_]
#         $baseName = [System.IO.Path]::GetFileNameWithoutExtension($currentName)
#         $parts = Split-TrackBaseName $baseName

#         $info = Get-LeadingSeparatedPrefixInfo -Title $parts.Title

#         if ($null -ne $info) {
#             $key = "$($info.PrefixNorm)|$($info.SepNorm)"

#             if (-not $prefixCounts.ContainsKey($key)) {
#                 $prefixCounts[$key] = 0
#             }

#             $prefixCounts[$key]++
#         }
#     }

#     # Only remove if the same prefix occurs in at least 2 files
#     $sharedPrefixKey = $null

#     foreach ($key in $prefixCounts.Keys) {
#         if ($prefixCounts[$key] -ge 2) {
#             $sharedPrefixKey = $key
#             break
#         }
#     }

#     if ($null -ne $sharedPrefixKey) {
#         $keysForLoop | ForEach-Object {
#             $currentName = $renameTable[$_]
#             $baseName = [System.IO.Path]::GetFileNameWithoutExtension($currentName)
#             $extension = [System.IO.Path]::GetExtension($currentName).ToLowerInvariant()

#             $parts = Split-TrackBaseName $baseName
#             $info = Get-LeadingSeparatedPrefixInfo -Title $parts.Title

#             if ($null -ne $info) {
#                 $key = "$($info.PrefixNorm)|$($info.SepNorm)"

#                 if ($key -eq $sharedPrefixKey) {
#                     $parts.Title = $info.Rest
#                 }
#             }

#             $newBaseName = Join-TrackBaseName $parts
#             $renameTable[$_] = "$newBaseName$extension"
#         }
#     }
# }

# We step through the files, and rename them
$keysForLoop | ForEach-Object { 
	# Write-Host "working on: $_ " # This line might need for tshooting
    $currentName = $renameTable[$_]


    Write-Host "CURRENT: [$currentName]"
    $currentName.ToCharArray() | ForEach-Object {
        if ([int]$_ -lt 32 -or [int]$_ -gt 126) {
            Write-Host ("SPECIAL: U+{0:X4} decimal={0}" -f [int]$_)
        }
    }

    # ez az eredeti
    #$extension = [System.IO.Path]::GetExtension($currentName).ToLowerInvariant()
    #$newName = [System.IO.Path]::GetFileNameWithoutExtension($currentName)
    try {
        $extension = [System.IO.Path]::GetExtension($currentName).ToLower()
        $newName = [System.IO.Path]::GetFileNameWithoutExtension($currentName)
    }
    catch {
        Write-Warning "Invalid filename: [$currentName]"
        Write-Warning $_.Exception.Message
        Start-Waiting
        continue
    }


    # Replacing leading letters with numbers
    $newName = $newName -replace '^ ?A','0'
    $newName = $newName -replace '^ ?B','1'
    $newName = $newName -replace '^ ?C','2'
    $newName = $newName -replace '^ ?D','3'
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

    # The only thing left is to replace the characters I don't like...
    $newName = $newName -replace ' _ ', "$PrettyColon " #[char]0xF025 # This is the "space-middledot-space" character
    $newName = $newName -replace ' -', ', ' # I do not like - in the file names, except after the number, so replacing it with a ,
    $newName = $newName -replace '- ', ', '
    $newName = $newName -replace '_', ' '
    $newName = $newName.Replace([char]0x0060, [char]0x0027)
    $newName = $newName -replace "[\u0060\u00B4\u2018\u2019\u02BC\u02CB\uFF40]", "'"
    $newName = $newName -replace ([char]0x00B4), "'"
    $newName = $newName -replace '-', [char]0x2013 # This is for the dashes that stay, replacing them to a longer one.
    $newName = $newName -replace '  ', ' ' # Remowing the double spaces
    $newName = $newName -replace '\[', '('
    $newName = $newName -replace '\]', ')'
    $newName = $newName -replace "gsign", "-"
    $newName = Convert-FromAllCaps($newName)

    $newName = [regex]::Replace($newName,'^(\d{1,4}\s*-\s*)[^:\uFF1A;,|]+[:\uFF1A;,|]\s*','${1}')
    $newName = [regex]::Replace($newName,'^(\d{1,4}\s*[-\u2013\u2014]\s*)[^-\u2013\u2014]+?\s+[-\u2013\u2014]\s+','${1}')

    $newName = $newName -replace '\sMov\.+(?=$|\s)', ' Movement'
    $newName = $newName -replace '\.+$', ''
    $newName = $newName -replace ';\s*', "$PrettyColon "

    # Now we remove duplicated whitespaces and trim them off from the beginning and the end
    #   of the file name, if they exist
    $newName = $newName -replace '\s+', ' '
    $newName = $newName.Trim()  

    # We put back the new name to the hash table
    $renameTable[$_] = "$newName$extension"       

    # Handle no match case in the beginning of the filename
    if (-not $matched) {
        Write-Host -ForegroundColor Red -NoNewline "No matching digits found for file "
        Write-Host -ForegroundColor Yellow "$newName$extension"
        $noMatch++
    }
}

# Perform the actual renames
$renameTable.Keys | ForEach-Object {
    $oldPath = Join-Path -Path $workingDir -ChildPath $_
    $newPath = Join-Path -Path $workingDir -ChildPath $renameTable[$_]

    Rename-Item -LiteralPath $oldPath -NewName $newPath
    Write-Host "Renamed: $_ -> $($renameTable[$_])" # This print out does not make too much, unless there was something wrong...
}

& .\Move-Art.ps1 -w $workingDir

# Remove not needed log, m3u, cue, accurip and url files
$CleanupExtensions = @(
    'log'
    'm3u'
    'm3u8'
    'cue'
    'accurip'
    'url'
)

foreach ($Extension in $CleanupExtensions) {
    Get-ChildItem -LiteralPath $workingDir -File -Force -Filter "*.$Extension" |
        Remove-Item -Force
}

# Cleanup specific files
$CleanupFiles = @(
    'Folder.auCDtect.txt'
    'foo_dr.txt'
)

foreach ($file in $CleanupFiles) {
    Remove-Item -LiteralPath (Join-Path $workingDir $file) `
        -Force -ErrorAction SilentlyContinue
}

Write-Host "Done"
Start-Waiting

if($noMatch -gt 0){ # There is a message that the user should read...
    Write-Host -ForegroundColor Red "`nThere were issues, please read the output.`nPress any key to exit..."
    Start-Waiting
}

#endregion Main