[CmdletBinding()] # For using the common parameters
    Param (
		[Parameter(Mandatory=$true)]
		[string]$workingDir,
		[string]$fileList
	)

$workingDir = $workingDir -replace '.$'
$fileList = $fileList -replace '.$'
#Set-Location $workingDir
Write-Host "List: '$fileList'"
$fileListArray = $fileList -split '(?<=flac) '
#$fileListArray | ForEach-Object { Write-Host $_ }

$fileListArray | ForEach-Object { 
	Write-Host "working on: $_ "
	$newName = $_ -replace ' -', ', '
	$newName = $newName -replace '  ', ' '
	$newName = $newName -replace '(\d\d?)(. ?)(.*)', '$1 - $3'
	$newName = Join-Path -Path $workingDir -ChildPath $newName
	$oldName = Join-Path -Path $workingDir -ChildPath $_
	
	Rename-Item -LiteralPath $oldName -NewName $newName
	#$fullNewName = $workingDir$newName
	#Write-Host "NN: $newName --- $oldName"
}

Write-Host "Done"

# For tshooting, or if you just want to see the messages, uncomment the following line
#Start-Sleep -s 290