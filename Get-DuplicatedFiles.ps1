<# 
.SYNOPSIS
    Finds duplicate files in a specified directory and groups them by folder.

.DESCRIPTION
    This script scans a given directory recursively, calculates SHA-256 hashes for all files,
    and identifies duplicates based on their hash values. The output is structured to show
    which folders contain duplicate files, listing file names beneath each grouped set.

.OUTPUTS
    - A full output file that lists duplicate files under their corresponding folders.
    - A folder-only output file that lists only the folders containing duplicates.

.PARAMETER Path
    Specifies the root directory to scan for duplicate files.

.PARAMETER OutputFile
    Specifies the file where the full duplicate report (folders + filenames) will be saved.

.PARAMETER FolderOnlyOutput
    Specifies the file where only the duplicate-containing folders will be saved.

.PARAMETER MinFileSizeKB
    Filters out files smaller than the specified size in kilobytes (default: 10 KB).

.NOTES
    - Uses `-LiteralPath` to handle special characters in file paths.
    - Provides a live progress indicator without cluttering the console.
    - Groups duplicate files properly so that folders are only listed once.

.EXAMPLE
    .\Find-Duplicates-GroupedByFolder.ps1 -Path "D:\" -OutputFile "D:\duplicates_grouped.txt" -FolderOnlyOutput "D:\duplicates_folders.txt" -MinFileSizeKB 50

    Scans the D:\ drive, finds duplicate files, and outputs:
    - `D:\D_duplicates_grouped.txt` → Full details (folders + filenames)
    - `D:\D_duplicates_folders.txt` → Folder-only listing

    It always puts the Drive letter in front of the output files.

.AUTHOR
    Geri The Biker
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------
param (
    [string]$Path = "C:\",                                  # Default to C:\ (change if needed)
    [string]$OutputFile = "duplicates_grouped.txt",         # Full output with file names
    [string]$FolderOnlyOutput = "duplicates_folders.txt",   # Output containing only folder groups
    [int]$MinFileSizeKB = 10,                               # Ignore files smaller than 10KB (change if needed)
    [switch]$CSV,                                           # Export to Excel (optional) 
    [string[]]$DoNotScan,                                   # List of folders to exclude from scanning 
    [switch]$DirExclusionOverride,                          # Override exclusions from mTools.ini   
    [switch]$FileExclusionOverride                          # Override file exclusions from mTools.ini
)

$runTimeTXT = "Runtime: "
$startTime = Get-Date
$accentColor = [System.ConsoleColor]::DarkYellow

# We gonna set the putput file names
# # Get the user's Documents\MusicLibraryTools\Results path
$ResultsPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'MusicLibraryTools'

# Ensure the Results folder exists
if (-not (Test-Path $ResultsPath)) {
    New-Item -ItemType Directory -Path $ResultsPath -Force | Out-Null
}

# Extract the drive letter from the provided path
$drive = $Path.Substring(0, 1) + "_"

# Prepend the Results path to the output files
$OutputFile = Join-Path $ResultsPath ($drive + $OutputFile)
$FolderOnlyOutput = Join-Path $ResultsPath ($drive + $FolderOnlyOutput)


# Check if the path to scan exists and load the MusicLibraryTools library
if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "Error: Path '$Path' does not exist."
    exit 1
}

$LibraryPath = "$env:USERPROFILE\Documents\GitHub\MusicLibraryTools\MusicLibraryTools.Library.psm1" # This has to be updated in the final version
if (Test-Path -Path $LibraryPath) {
    Import-Module -Name $LibraryPath -Force
    Write-Host "MusicLibraryTools library module imported successfully."
} else {
    Write-Warning "Library module not found at '$LibraryPath'. Ensure the repository includes it."
    exit 1
}

#-------------------------------------------------------------[Main]--------------------------------------------------------------
# ✅ Read exclusions from mTools.ini
$exclusions = Get-ExclusionsFromINI

if(-not $DirExclusionOverride) {
    Write-Host "Excluded directories from mTools.ini: $($exclusions["excludeDirs"] -join ', ')"
    $excludedDirs = $exclusions["excludeDirs"]
    Write-Host "Excluding directories: $($excludedDirs -join ', ')"
}
if(-not $FileExclusionOverride) {
    Write-Host "Excluded file types from mTools.ini: $($exclusions["excludeFiles"] -join ', ')"
    $excludedFiles = $exclusions["excludeFiles"]
    Write-Host "Excluding file types: $($excludedFiles -join ', ')"
}

$sizeNameGroups = @{}

Write-Host "Scanning files in $Path..."

# Get all files (filtering by size for performance)
# $files = Get-ChildItem -LiteralPath $Path -Recurse -File | Where-Object {
#     ($MinFileSizeKB -eq 0 -or $_.Length -gt ($MinFileSizeKB * 1KB)) -and  # Allow scanning all files if 0 is given
#     ($null -eq $DoNotScan -or -not ($DoNotScan | Where-Object { $_ -and $_ -ne "" -and $_.StartsWith($_.DirectoryName, [System.StringComparison]::OrdinalIgnoreCase) }))
# }
# ✅ Step 1: Collect all files first
Write-ColoredText -TextPairs "Collecting all files in ", $Path, ". This may take a while, and as this is one operation, I cannot display status info..." -AccentColor "Yellow"
$allFiles = Get-ChildItem -LiteralPath $Path -Recurse -File

# ✅ Step 2: Filter files AFTER collection. It is not really possible to filter all this in one go, that is why the filtering is done in a separate step
$files = @()  # Initialize as an empty array
foreach ($file in $allFiles) {

    # ✅ Check if directory is excluded first, skips all other tests
    if(-not $DirExclusionOverride) {
        if ($excludedDirs | Where-Object { $file.DirectoryName -match [regex]::Escape($_) }) {
            continue  # Skip all files inside this directory
        }
    }

    # ✅ Check if file type is excluded (only if directory wasn't already excluded) 
    if(-not $FileExclusionOverride) {
        if ($excludedFiles -contains $file.Extension.TrimStart('.')) {
            continue  # Skip excluded file types
        }
    }

    # ✅ Always exclude shortcut (.lnk) files, regardless of override
    if ($file.Extension -eq ".lnk") {
        continue  # Skip .lnk files early
    }
    # ✅ Check minimum file size
    if ($MinFileSizeKB -ne 0 -and $file.Length -le ($MinFileSizeKB * 1KB)) {
        continue  # Skip small files
    }

    # ✅ If it passed all checks (meaning should be checked), add to final file list
    $files += $file
}

############################################################################################################

$totalFiles = $files.Count
$processedFiles = 0

# Process each file with a progress indicator
foreach ($file in $files) {
    # # Skip files if their path contains ".lnk"
    # if ($file.FullName -match "\.lnk") { 
    #     continue 
    # }

    $processedFiles++
    Use-ProgressIndicator -Current $processedFiles -Total $totalFiles -Message $file.FullName    
    
    try {
        # Group files by (size + name) before hashing
        $key = "$($file.Length)_$($file.Name)"
        if ($sizeNameGroups.ContainsKey($key)) {
            $sizeNameGroups[$key] += $file.FullName
        } else {
            $sizeNameGroups[$key] = @($file.FullName)
        }
    } catch {
        Write-Host "`rError processing file: $($file.FullName)" -ForegroundColor Red
    }
}


Write-ColoredText -TextPairs "Processing ", $processedFiles, " files completed. Starting ashing and grouping duplicates..." -AccentColor Green -clearLine 

$hashes = @{}
$processedHashes = 0
$totalHashFiles = ($sizeNameGroups.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | ForEach-Object { $_.Value.Count } | Measure-Object -Sum).Sum

foreach ($group in $sizeNameGroups.GetEnumerator()) {
    if ($group.Value.Count -gt 1) {  # Only process groups with duplicates
        foreach ($filePath in $group.Value) {
            $processedHashes++
            Use-ProgressIndicator -Current $processedHashes -Total $totalHashFiles -Message "$filePath" -Prefix "Hashing:"
            $hash = Get-PartialFileHash -FilePath $filePath # -BytesToRead 512KB # if you want to override the default 1MB. 
            if ($null -ne $hash) {
                if ($hashes.ContainsKey($hash)) {
                    $hashes[$hash] += $filePath
                } else {
                    $hashes[$hash] = @($filePath)
                }
            }
        }
    }
}

# Clear the progress indicator with message
Write-HostClearLine -Message ""
Write-ColoredText -TextPairs "Hashing and grouping of ", $totalHashFiles, " files completed." -AccentColor Green 

# Filter out unique files (keep only duplicates
$duplicates = $hashes.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }

# Hashtable for organizing grouped output by folder
$folderGroups = @{}

if($CSV) {
    $csvData = @()
}   

foreach ($dup in $duplicates) {
    $fileList = $dup.Value

    # Get the unique folders where duplicates exist
    $folderList = $fileList | ForEach-Object { [System.IO.Path]::GetDirectoryName($_) } | Sort-Object -Unique

    # Convert folder array into multi-line format
    $folderKey = $folderList -join "`r`n"

    # Store filenames under the grouped folder key
    if (-not $folderGroups.ContainsKey($folderKey)) {
        $folderGroups[$folderKey] = @()

        # ✅ Add to Excel at the same time
        if ($CSV) {
            $csvData += [PSCustomObject]@{ FolderName = "*****************"; FileName = "" }
            foreach ($folder in $folderList) {
                $csvData += [PSCustomObject]@{ FolderName = $folder; FileName = "" }
            }
        }
    }
    
    # Add the unique filenames for this duplicate group
    $uniqueFiles = $fileList | Sort-Object | Get-Unique
    $folderGroups[$folderKey] += $uniqueFiles | ForEach-Object { [System.IO.Path]::GetFileName($_) }
}

if ($folderGroups.Count -gt 0) { 
    # Write results to output files
    Write-Host "Found $(@($duplicates).Count) duplicate files in $processedFiles files." -ForegroundColor Yellow
    Write-Host "Writing results to $OutputFile and $FolderOnlyOutput..."
    if(Test-Path -LiteralPath $OutputFile) { Remove-Item -LiteralPath $OutputFile } # Clear previous content
    if(Test-Path -LiteralPath $FolderOnlyOutput) { Remove-Item -LiteralPath $FolderOnlyOutput}  # Clear previous content

    $groupCounter = 0
    foreach ($folderKey in $folderGroups.Keys | Sort-Object) {
        # "`rWriting folder group $folderKey..." 
        if($groupCounter -gt 0) {
            "`r`n***************" | Out-File -LiteralPath $OutputFile -Append
            "`r`n***************" | Out-File -LiteralPath $FolderOnlyOutput -Append
        }
        # Write the folder grouping (one per line with a divider)
        "$folderKey`r`n" | Out-File -LiteralPath $OutputFile -Append
        "$folderKey`r`n" | Out-File -LiteralPath $FolderOnlyOutput -Append
        
        # Write the filenames under the folder grouping (only in full output)
        $folderGroups[$folderKey] | Sort-Object | Get-Unique | ForEach-Object { "    $_" } | Out-File -LiteralPath $OutputFile -Append
        $groupCounter++
    }

    if ($CSV) {
        $excelFile = [System.IO.Path]::ChangeExtension($OutputFile, ".xlsx")
        $baseName = $excelFile -replace "\.xlsx$", ""
        #Write-ColoredText -TextPairs "Exporting to Excel: ", $excelFile -AccentColor Green

        # Check if the Excel file is locked and rename if needed
        $counter = 1
        while ((Test-Path $excelFile) -and (Test-FileLocked -FilePath $excelFile)) {
            Write-Host "File is locked or already exists: $excelFile" -ForegroundColor Magenta
            $excelFile = "$baseName`_($counter).xlsx"
            $counter++
        }

        # Export to Excel with automatic table formatting
        Convert-TextToExcel -InputFile $OutputFile -OutputFile $excelFile 
    } 
} else {
    # No duplicates found
    Write-Host "No duplicate files found. No output files generated." -ForegroundColor Green
}



#----------------------------------------------------------[Completion]----------------------------------------------------------
# Processed
Write-ColoredText -TextPairs "Processed ",$totalFiles, " alltogether." -AccentColor $accentColor 

# Duplicates
Write-ColoredText -TextPairs "Done!`nResults saved in '", $OutputFile, "'`n             and '",$FolderOnlyOutput, "'" -AccentColor $accentColor -NoNewLine
if($CSV) { 
    Write-ColoredText -TextPairs "`n     and also in '", $excelFile, "'." -AccentColor $accentColor 
}else{ 
    Write-Host "." 
}

# Runtime
$endTime = Get-Date
$runTime = [Math]::Round((New-TimeSpan -Start $startTime -end $endTime).totalseconds,2)
Write-ColoredText -TextPairs $runTimeTXT, $runTime, " seconds." -AccentColor $accentColor