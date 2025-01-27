<# 
.SYNOPSIS
    Safely removes duplicate files and deletes empty folders based on a marked duplicates file.

.DESCRIPTION
    This script reads a structured duplicates file (e.g., `duplicates_grouped.txt`) where specific
    folders are marked with `*delete*`. It removes only the listed duplicate files from these
    folders and deletes the folders **only if they become empty**.

    A confirmation step can be enabled to review deletions before execution.

.OUTPUTS
    - Deletes duplicate files **only** from folders marked with `*delete*`
    - Removes folders **only if they become empty**

.PARAMETER InputFile
    Specifies the duplicates file to read. This file must follow the format where:
    - Duplicate groups are separated by `*****************`
    - Folders marked for deletion start with `*delete*`
    - Duplicate file names are listed under each folder group

.PARAMETER ConfirmBeforeDeleting
    If specified, prompts the user before deleting each group of files.

.EXAMPLE
    .\Remove-Duplicates-Safely.ps1 -InputFile "duplicates_grouped.txt" -ConfirmBeforeDeleting

    Reads `duplicates_grouped.txt`, identifies duplicate files to delete, and asks for confirmation
    before deletion.

.EXAMPLE
    .\Remove-Duplicates-Safely.ps1 -InputFile "D_duplicates_grouped.txt"

    Reads `duplicates_grouped.txt` and deletes duplicate files **without confirmation**.

.NOTES
    - Uses `-LiteralPath` to handle special characters in file paths.
    - Ensures **no entire folder is deleted unless empty**.
    - Built-in **confirmation mode** to prevent accidental data loss.

.AUTHOR
    Geri The Biker 
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------
param (
    [string]$InputFile = "duplicates_grouped.txt",  # File with deletion indicators
    [switch]$ConfirmBeforeDeleting,               # Ask for confirmation before deletion
    [switch]$DryRun                               # Simulate deletions without actual changes
)

# Ensure the input file exists
if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Host "Error: Input file '$InputFile' not found." -ForegroundColor Red
    exit 1
}

# If DryRun is enabled, disable confirmation (since no real deletions happen)
if ($DryRun) {
    Write-Host "`nRunning in DRY RUN mode. No files will be deleted!" -ForegroundColor Green
    $ConfirmBeforeDeleting = $false
} else {
    Write-Host "`nRunning in NORMAL mode. Files will be deleted!" -ForegroundColor Yellow
}

#-----------------------------------------------------------[Functions]------------------------------------------------------------
#################################################################################
# FUNCTION: Simulates or actually deletes duplicate files from marked folders
#################################################################################
function Remove-Duplicates {
    param (
        [string[]]$folders,
        [string[]]$files,
        [switch]$confirm,
        [switch]$dryRun
    )

    if ($dryRun) {
        #Write-Host "`nDEBUG: Inside Remove-Duplicates - Processing Dry Run" -ForegroundColor Yellow
        #Write-Host "DEBUG: Folders: $folders" -ForegroundColor Magenta
        #Write-Host "DEBUG: Files: $files" -ForegroundColor Cyan
        #Write-Host "`nThe following files will be deleted in a real run:" -ForegroundColor Yellow
        #Write-Host $folders + ", " + $files
        foreach ($folder in $folders) {
            Write-Host "`n$folder" -ForegroundColor Magenta
            foreach ($file in $files) {
                Write-Host "   $file" -ForegroundColor Cyan
            }
        }
        return
    }
    

    Write-Host "`n*****************" -ForegroundColor Yellow
    Write-Host "Processing duplicate group:" -ForegroundColor Yellow

    $folders | ForEach-Object { Write-Host "  Folder: $_" -ForegroundColor Magenta }
    $files | ForEach-Object { Write-Host "    File: $_" -ForegroundColor Cyan }

    if ($confirm) {
        $response = Read-Host "Delete these files? (yes/no)"
        if ($response -ne "yes") {
            Write-Host "Skipping deletion for this group." -ForegroundColor Red
            return
        }
    }

    foreach ($folder in $folders) {
        foreach ($file in $files) {
            $filePath = Join-Path -Path $folder -ChildPath $file

            if (Test-Path -LiteralPath $filePath) {
                Write-Host "Deleting: $filePath" -ForegroundColor Red
                Remove-Item -LiteralPath $filePath -Force
            } else {
                Write-Host "File not found (skipping): $filePath" -ForegroundColor Yellow
            }
        }

        if ((Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue).Count -eq 0) {
            Write-Host "Removing empty folder: $folder" -ForegroundColor Red
            Remove-Item -LiteralPath $folder -Force
        }
    }
}

#-------------------------------------------------------------[Main]--------------------------------------------------------------
Write-Host "Checking if there is any folders to be deleted..." -ForegroundColor Cyan
$foldersToDelete = Get-Content -LiteralPath $InputFile | Where-Object { $_ -match "^\*delete\*" }

if ($foldersToDelete.Count -eq 0) {
    Write-Host "No folders marked for deletion, exiting..." -ForegroundColor Yellow
    exit 0
} else {
    if($foldersToDelete.Count -eq 1){
        Write-Host "There is $($foldersToDelete.Count) folder indicated to be deleted." -ForegroundColor Yellow
    } else {
        Write-Host "There are $($foldersToDelete.Count) folders indicated to be deleted." -ForegroundColor Yellow
    }
    Write-Host "Proceeding with duplicate cleanup..." -ForegroundColor Yellow
}

Write-Host "Scanning for unsafe delete operations..." -ForegroundColor Cyan

# Variables to track duplicate groups
$unsafeGroups = @()
$currentGroup = @()
$allMarkedForDelete = $true  # Assume all are marked, and check as we go

# First pass: Check for fully marked deletion groups
Get-Content -LiteralPath $InputFile | ForEach-Object {
    $line = $_.Trim()

    if ($line -match "^\*{10,}$") {
        if ($currentGroup.Count -gt 0 -and $allMarkedForDelete) {
            $unsafeGroups += "`n*****************`n" + ($currentGroup -join "`n")
        }
        $currentGroup = @()
        $allMarkedForDelete = $true
    }
    elseif ($line -match "^\*delete\*(.+)") {
        $currentGroup += $matches[1]
    }
    elseif ($line -match "^[A-Za-z]:\\") {
        $currentGroup += $line
        $allMarkedForDelete = $false  # At least one folder is safe
    }
}

if ($currentGroup.Count -gt 0 -and $allMarkedForDelete) {
    $unsafeGroups += "`n*****************`n" + ($currentGroup -join "`n")
}

# If unsafe groups exist, print them and exit
if ($unsafeGroups.Count -gt 0) {
    Write-Host "`nWARNING: The following groups have ALL folders marked for deletion!" -ForegroundColor Red
    $unsafeGroups | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    Write-Host "`nABORTING SCRIPT. No files were deleted!" -ForegroundColor Red
    exit 1
}

Write-Host "No unsafe delete groups detected. Proceeding..." -ForegroundColor Green

# Second pass: Process valid groups
$currentFolders = @()
$filesToDelete = @()

if ($DryRun) {
    Write-Host "`nThe following files will be deleted in a real run:" -ForegroundColor Yellow
}
$processingDeleteGroup = $false  # initialize processing flag
# Read the entire input file into an array
$lines = Get-Content -LiteralPath $InputFile
$currentFolders = @()
$deleteMarkedFolders = @()
$filesToDelete = @()
$processingDeleteGroup = $false

foreach ($line in $lines) {
    $line = $line.Trim()

    if ($line -match "^\*{10,}$") {
        # Process the previous group before resetting the variables
        if ($deleteMarkedFolders.Count -gt 0 -and $filesToDelete.Count -gt 0) {
            #Write-Host "`nDEBUG: Processing group - Delete Folders: $deleteMarkedFolders - Files: $filesToDelete" -ForegroundColor Cyan
            Remove-Duplicates -folders $deleteMarkedFolders -files ($filesToDelete | Select-Object -Unique) -confirm:$ConfirmBeforeDeleting -dryRun:$DryRun
        }
        # Reset variables for the next group
        $currentFolders = @()
        $deleteMarkedFolders = @()
        $filesToDelete = @()
        $processingDeleteGroup = $false
    }
    elseif ($line -match "^\*delete\*(.+)") {
        $currentFolders += $matches[0]
        $deleteMarkedFolders += $matches[0] -replace "^\*delete\*", ""  # Remove *delete* prefix, store for deletion
        $processingDeleteGroup = $true
    }
    elseif ($line -match "^[A-Za-z]:\\") {
        $currentFolders += $line
    }
    elseif ($line -match "^[^:*?<>|]+(\.[a-zA-Z0-9]+)?$") {
        # Only add files if at least one folder in this group is marked for deletion
        if ($processingDeleteGroup) {
            $filesToDelete += $matches[0].Trim()
            #Write-Host "DEBUG: Adding file to delete -> '$($matches[0])'" -ForegroundColor Green
        } #else {
        #     Write-Host "Skipping file (not in a delete-marked folder): $line" -ForegroundColor Yellow
        # }
    }
}

# Ensure the last group is processed after the loop ends
if ($deleteMarkedFolders.Count -gt 0 -and $filesToDelete.Count -gt 0) {
    #Write-Host "`nDEBUG: Processing last group - Delete Folders: $deleteMarkedFolders - Files: $filesToDelete" -ForegroundColor Cyan
    Remove-Duplicates -folders $deleteMarkedFolders -files ($filesToDelete | Select-Object -Unique) -confirm:$ConfirmBeforeDeleting -dryRun:$DryRun
} 
# else {
#     Write-Host "`nNo groups to process. $($deleteMarkedFolders.Count), $($filesToDelete.Count)" -ForegroundColor Yellow
# }




Write-Host "`nDuplicate cleanup completed!" -ForegroundColor Green
