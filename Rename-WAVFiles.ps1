# Rename-WavFiles.ps1
param (
    [string]$FolderPath = "."
)

# Szűrés WAV fájlokra
$wavFiles = Get-ChildItem -Path $FolderPath -Filter *.wav | Sort-Object Name

# CSV előkészítés
$csvPath = Join-Path $FolderPath "mapping.csv"
$mapping = @()

# Átnevezés + logolás
$i = 1
foreach ($file in $wavFiles) {
    $newName = "{0:D2}.wav" -f $i
    Rename-Item -Path $file.FullName -NewName $newName
    $mapping += [PSCustomObject]@{
        NewFile     = $newName
        OriginalFile = $file.Name
    }
    $i++
}

# Mentés CSV-be
$mapping | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "Átnevezés kész. Mapping fájl: $csvPath"
