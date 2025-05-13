param (
    [Parameter(Mandatory = $true)]
    [string]$LowResRoot,

    [Parameter(Mandatory = $true)]
    [string]$HiResRoot,

    [switch]$DryRun
)
# Start runtime measurement
$startTime = Get-Date

if(-not (Test-Path $LowResRoot)){Write-Error "Source root $LowResRoot does not exists, exiting..."}
if(-not (Test-Path $HiResRoot)) {Write-Error "Target root $HiResRoot does not exists, exiting..."}

# Load Progress Indicator
$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LibraryPath = Join-Path -Path $ScriptFolder -ChildPath "MusicLibraryTools.Library.psm1"
if (Test-Path $LibraryPath) {
    Import-Module -Force $LibraryPath
} else {
    Write-Host "⚠ Library not found: $LibraryPath"
}



# Prepare error logging
$logFolder = Join-Path $ScriptFolder "logs"
if (-not (Test-Path $logFolder)) { New-Item -ItemType Directory -Path $logFolder | Out-Null }

$lastLog = Join-Path $logFolder "MoveErrors_last.txt"
$currentLog = Join-Path $logFolder "MoveErrors_current.txt"
if (Test-Path $currentLog) {
    Move-Item -Force -LiteralPath $currentLog -Destination $lastLog
}
$logBuffer = @()

# Get all band folders from LowRes
$bandFolders = Get-ChildItem -LiteralPath $LowResRoot -Directory
$total = $bandFolders.Count
$current = 0

foreach ($band in $bandFolders) {
    $current++
    Use-ProgressIndicator -Current $current -Total $total -Message "Band: $($band.Name)"

    $name = $band.Name

    # Try to find matching tagged folder in HiResRoot
    $matchingTagged = Get-ChildItem -LiteralPath $HiResRoot -Directory |
        Where-Object { $_.Name -like "$name {*" }

    if ($matchingTagged) {
        foreach ($album in Get-ChildItem -LiteralPath $band.FullName -Directory) {
            $targetPath = Join-Path -Path $matchingTagged.FullName -ChildPath $album.Name

            if ($DryRun) {
                Use-ProgressIndicator -Current $current -Total $total -Message "🟡 DryRun: Would move '$($album.FullName)' → '$targetPath'"
                Start-Waiting
            } else {
                try {
                    Move-Item -LiteralPath $album.FullName -Destination $targetPath
                } catch {
                    $msg = "❌ Failed to move '$($album.FullName)' → '$targetPath': $_"
                    Use-ProgressIndicator -Current $current -Total $total -Message $msg
                    $logBuffer += $msg
                }
            }
        }

        # Delete empty folder after move
        if (-not $DryRun -and (Get-ChildItem -LiteralPath $band.FullName)) {
            $msg = "⚠ Folder not empty, not deleted: $($band.Name)"
            Use-ProgressIndicator -Current $current -Total $total -Message $msg
            $logBuffer += $msg
        } elseif (-not $DryRun) {
            Remove-Item -LiteralPath $band.FullName -Force
            Use-ProgressIndicator -Current $current -Total $total -Message "✅ Deleted empty folder: $($band.Name)"
        }
    } else { # Matching tagged else
        $targetPath = Join-Path -Path $HiResRoot -ChildPath $band.Name
        if ($DryRun) {
            Use-ProgressIndicator -Current $current -Total $total -Message "🟡 DryRun: Would move '$($band.FullName)' → '$targetPath'"
            Start-Waiting
        } else {
            try {
                Move-Item -LiteralPath $band.FullName -Destination $targetPath
            } catch {
                $msg = "❌ Failed to move folder: '$($band.FullName)' → '$targetPath': $_"
                Use-ProgressIndicator -Current $current -Total $total -Message $msg
                $logBuffer += $msg
            }
        }
    }
}

Write-Host "`r`n"
# Write log if any errors occurred
if ($logBuffer.Count -gt 0) {
    $logBuffer | Out-File -Encoding UTF8 -FilePath $currentLog
    Write-Host "⚠ Errors logged to: $currentLog"
}

# Runtime info
$endTime = Get-Date
$elapsed = $endTime - $startTime
Write-Host "⏱ Runtime: $($elapsed.ToString())"
