[CmdletBinding()] # For using the common parameters
    Param (
		[Parameter(Mandatory=$true)]
		[string]$workingDir
	)


function Is-SymbolicLinkRelative {
    param (
        [string]$linkPath  # Path to the symbolic link or junction
    )

    # Get the link target
    $linkTarget = (Get-Item -Path $linkPath).Target

    # Check if the link target is relative or absolute
    if ($linkTarget -match '^[a-zA-Z]:\\' -or $linkTarget -match '^\\\\') {
        Write-Output "Absolute"
    } else {
        Write-Output "Relative"
    }
}

function Is-LnkFileRelative {
    param (
        [string]$shortcutPath  # Path to the .lnk file
    )

    # Create a Shell COM object and load the shortcut
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)

    # Get the target path
    $targetPath = $shortcut.TargetPath

    # Check if the target path is relative or absolute
    if ($targetPath -match '^[a-zA-Z]:\\' -or $targetPath -match '^\\\\') {
        Write-Output "Absolute"
    } else {
        Write-Output "Relative"
    }
}

# Exe
$runTimeTXT = "Runtime: "
$startTime = Get-Date

Get-ChildItem -LiteralPath $workingDir -Recurse | ForEach-Object {
    if ($_.Extension -eq ".lnk") {
        Write-Output "$($_.FullName) is $(Is-LnkFileRelative -shortcutPath $_.FullName)"
    } elseif ($_.Attributes -match "ReparsePoint") {
        Write-Output "$($_.FullName) is $(Is-SymbolicLinkRelative -linkPath $_.FullName)"
    }
}

$endTime = Get-Date
$runTime = [Math]::Round((New-TimeSpan -Start $startTime -end $endTime).totalseconds,2)
Write-Host $runTimeTXT$runTime "seconds."