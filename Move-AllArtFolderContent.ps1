[CmdletBinding()] # For using the common parameters
    Param (
		[Parameter(Mandatory=$true)]
		[string]$drive
	)

# Preaparation
$runTimeTXT = "Runtime: "
$startTime = Get-Date
$drive = $drive + ":\"

# Main
# Get all "Artwork" directories
Get-ChildItem -Path $drive -Directory -Recurse -Filter "Artwork" | ForEach-Object {
    $artworkFolder = $_.FullName
    $parentFolder = Split-Path -Path $artworkFolder -Parent

    # Move all contents of the "Artwork" folder one level up
    Get-ChildItem -Path $artworkFolder | ForEach-Object {
		$newName = $_.Name -replace '^', 'zArt_'
        $destination = Join-Path -Path $parentFolder -ChildPath $newName
		$source = Join-Path -Path $artworkFolder -ChildPath $_.Name
        Move-Item -LiteralPath $source -Destination $destination
		#Write-Output "File $source has been moved!"
    }

    # Remove the now empty "Artwork" folder
    Remove-Item -LiteralPath $artworkFolder -Force -Recurse
	Write-Output "Folder `"$artworkFolder`" has been fixed!"
	#Start-Sleep -s 5
}

# Finishing
$endTime = Get-Date
$runTime = [Math]::Round((New-TimeSpan -Start $startTime -end $endTime).totalseconds,2)
Write-Host $runTimeTXT$runTime "seconds."
