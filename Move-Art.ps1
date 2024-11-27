[CmdletBinding()] # For using the common parameters
    Param (
		[Parameter(Mandatory=$true)]
		[string]$workingDir
	)

# Ensure the working directory ends with a backslash
# In "Unreal Commander" it is not necessary, uncomment if needed.
#if (-not $workingDir.EndsWith("\")) {
#    $workingDir += "\"
#}

# For some reason "Unreal Commander" puts a " character at the end of the path, we have to cut it off...
# If u using the script from command line, or possibly from other commander, you might need to comment out this line
$workingDir = $workingDir -replace '.$'


#$workingDir = [System.Management.Automation.WildcardPattern]::Escape($workingDir)
$artPath = Join-Path -Path $workingDir -ChildPath Artwork

# For tshooting
Write-Host "Working Dir: $workingDir"
Write-Host "ArtPath: $artPath"

# Get all files in the folder (supports wildcards) using Get-ChildItem
$files = Get-ChildItem -LiteralPath $artPath -Filter "*"

# Move each file. "LiteralPath" cannot use wildcard, that is why we had to put together this list, and do one-by-one
foreach ($file in $files) {
	$newName = $file.Name -replace '^', 'zArt'
	$newName = Join-Path -Path $workingDir -ChildPath $newName
    Move-Item -LiteralPath $file.FullName -Destination $newName
}

# Now we remove the not needed empty folder
Remove-Item -LiteralPath $artPath 

Write-Host "Done"

# For tshooting, or if you just want to see the messages, uncomment the following line
#Start-Sleep -s 290