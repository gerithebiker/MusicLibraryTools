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
    [string]$Path = "C:\",                              # Default to C:\ (change if needed)
    [string]$OutputFile = "duplicates_grouped.txt",     # Full output with file names
    [string]$FolderOnlyOutput = "duplicates_folders.txt", # Output containing only folder groups
    [int]$MinFileSizeKB = 10,                           # Ignore files smaller than 10KB (change if needed)
    [switch]$CSV    
)

$runTimeTXT = "Runtime: "
$startTime = Get-Date

$drive = $Path.Substring(0, 1) + "_"
$OutputFile = $drive + $OutputFile
$FolderOnlyOutput = $drive + $FolderOnlyOutput

#-------------------------------------------------------------[Main]--------------------------------------------------------------
# Ensure the path exists
if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "Error: Path '$Path' does not exist."
    exit 1
}

# Hashtable to store hash -> file paths
$hashes = @{}

Write-Host "Scanning files in $Path..."

# Get all files (filtering by size for performance)
$files = Get-ChildItem -LiteralPath $Path -Recurse -File | Where-Object {
    ($MinFileSizeKB -eq 0 -or $_.Length -gt ($MinFileSizeKB * 1KB)) -and  # Allow scanning all files if 0 is given
    ($null -eq $DoNotScan -or -not ($DoNotScan | Where-Object { $_ -and $_ -ne "" -and $_.StartsWith($_.DirectoryName, [System.StringComparison]::OrdinalIgnoreCase) }))
}

$totalFiles = $files.Count
$processedFiles = 0

# Process each file with a progress indicator
foreach ($file in $files) {
    # Skip files if their path contains ".lnk"
    if ($file.FullName -match "\.lnk") { 
        continue 
    }

    $processedFiles++
    $progress = [math]::Floor(($processedFiles / $totalFiles) * 100)
    
    # Overwriting progress indicator
    Write-Host "`rProcessing files: $processedFiles / $totalFiles ($progress%)" -NoNewline

    try {
        # Compute SHA-256 hash using -LiteralPath
        $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 | Select-Object -ExpandProperty Hash

        # Store the file path under its hash
        if ($hashes.ContainsKey($hash)) {
            $hashes[$hash] += $file.FullName
        } else {
            $hashes[$hash] = @($file.FullName)
        }
    } catch {
        Write-Host "`rError processing file: $($file.FullName)" -ForegroundColor Red
    }
}

# Ensure progress bar is cleared after processing
Write-Host "`rProcessing complete!                       `n"

# Filter out unique files (keep only duplicates)
$duplicates = $hashes.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }

# Hashtable for organizing grouped output by folder
$folderGroups = @{}

foreach ($dup in $duplicates) {
    $fileList = $dup.Value

    # Get the unique folders where duplicates exist
    $folderList = $fileList | ForEach-Object { [System.IO.Path]::GetDirectoryName($_) } | Sort-Object -Unique

    # Convert folder array into multi-line format
    $folderKey = $folderList -join "`r`n"

    # Store filenames under the grouped folder key
    if (-not $folderGroups.ContainsKey($folderKey)) {
        $folderGroups[$folderKey] = @()
    }
    
    # Add the unique filenames for this duplicate group
    $folderGroups[$folderKey] += ($fileList | ForEach-Object { [System.IO.Path]::GetFileName($_) })
}

# Write results to output files
Write-Host "Found $(@($duplicates).Count) duplicate files in $processedFiles files."
Write-Host "Writing results to $OutputFile and $FolderOnlyOutput..."
if(Test-Path -LiteralPath $OutputFile) { Remove-Item -LiteralPath $OutputFile } # Clear previous content
if(Test-Path -LiteralPath $FolderOnlyOutput) { Remove-Item -LiteralPath $FolderOnlyOutput}  # Clear previous content

if ($folderGroups.Count -gt 0) { 
    $groupCounter = 0
    foreach ($folderKey in $folderGroups.Keys | Sort-Object) {
        Write-Host "`rWriting folder group $folderKey..." 
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
        write-host "Exporting to Excel: $excelFile" -ForegroundColor Green

        function Test-FileLocked {
            param ([string]$FilePath)
            write-host "Checking if file is locked: $FilePath"
            try {
                $fs = [System.IO.File]::Open($FilePath, 'Open', 'Write')
                $fs.Close()
                Remove-Item -Force $excelFile
                return $false  # File is NOT locked
            } catch {
                return $true   # File is locked
            }
        }

        # Check if the Excel file is locked and rename if needed
        $counter = 1
            while ((Test-Path $excelFile) -and (Test-FileLocked -FilePath $excelFile)) {
                write-host "File is locked or already exists: $excelFile" -ForegroundColor Yellow
                $excelFile = "$baseName`_($counter).xlsx"
                $counter++
            }
        # Export to Excel with automatic table formatting
        $csvData | Export-Excel -Path $excelFile -TableName "Duplicates" -AutoSize -FreezeTopRow

        Write-Host "Excel Exported: $excelFile"
    } 
} else {
    Write-Host "No duplicate files found. No output files generated."
}



#----------------------------------------------------------[Completion]----------------------------------------------------------
# Display completion message
Write-Host "Done! Results saved in '$OutputFile' and '$FolderOnlyOutput'."
$endTime = Get-Date
$runTime = [Math]::Round((New-TimeSpan -Start $startTime -end $endTime).totalseconds,2)
Write-Host $runTimeTXT$runTime "seconds."