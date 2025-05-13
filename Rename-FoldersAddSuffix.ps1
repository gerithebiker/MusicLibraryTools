param (
    [Parameter(Mandatory = $true)]
    [string]$StartFolder,

    [switch]$DryRun
)

$startTime = Get-Date

# Ensure the folder exists
if (-not (Test-Path -LiteralPath $StartFolder -PathType Container)) {
    Write-Host "❌ The specified path does not exist: $StartFolder"
    exit 1
}

$ScriptFolder  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LibraryPath   = Join-Path -Path $ScriptFolder -ChildPath "MusicLibraryTools.Library.psm1"
Import-Module $LibraryPath -Force

$bandFolders = Get-ChildItem -LiteralPath $StartFolder -Directory
$totalFolders = $bandFolders.Count
$processedFolders = 0
$up = 0
$allAlbums = 0

foreach ($band in $bandFolders) {
    $albumFolders = Get-ChildItem -LiteralPath $band.FullName -Directory
    $totalAlbums = $albumFolders.Length
    $allAlbums = $allAlbums + $totalAlbums
    $processedFolders++
    $up = 1
    $processedAlbums = 0
    Use-ProgressIndicator -Current $processedFolders -Total $totalFolders -Message $band -LinesUp $up #-Prefix "Working on " 

    foreach ($folder in $albumFolders) {
        $folderName = $folder.Name
        $processedAlbums++
        # Check if the folder name starts with 4 digits
        if ($folderName -match '^\d{4}') {
            # Check if the suffix is already present
            if ($folderName -notlike '* (16-44)') {
                $newName = "$folderName (16-44)"
                #$newPath = Join-Path -Path $folder.Parent.FullName -ChildPath $newName

                if ($DryRun) {
                    Use-ProgressIndicator -Current $processedAlbums -Total $totalAlbums -Message "🟡 DryRun: '$folderName' → '$newName'"
                } else {
                    try {
                        Rename-Item -LiteralPath $folder.FullName -NewName $newName
                        Use-ProgressIndicator -Current $processedAlbums -Total $totalAlbums -Message "✅ Renamed: '$folderName' → '$newName'"
                    } catch {
                        Use-ProgressIndicator -Current $processedAlbums -Total $totalAlbums -Message "❌ Failed to rename '$folderName': $_"
                    }
                }
            } else {
                Use-ProgressIndicator -Current $processedAlbums -Total $totalAlbums -Message "ℹ️ Already renamed: $folderName"
            }
        }
    }
}

Write-Host "`r`nProcessed $allAlbums albums."
$endTime = Get-Date
$runTime = [Math]::Round((New-TimeSpan -Start $startTime -end $endTime).totalseconds,2)
Write-Host "Runtime: $runTime seconds."
