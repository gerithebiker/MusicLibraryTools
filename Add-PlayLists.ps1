<#
.SYNOPSIS
  Creates m3u playlist files in each directories, where there is at least one music file.

.DESCRIPTION
  This script is intended to create m3u playlist files in each of the directories where there is at least one music file. It does not expect any arguments. If non give, it will use the current directory as a starting point. If there is already an m3u file in a folder, the it will skip creating one, unless the "force" switch is enable. If both "force" and "delete" is enabled, then before creating one, it will delete the existing m3u files. "delete" works only if "force" is enabled.
  
  If you are lazy like me, and do not like to type in the full command name, then put create a permanent alias. You can find your profile file typing in the following line in a PowerShell terminal:
  C:\> $PROFILE
  The anser will be something like:
  C:\Users\YourUserID\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
  
  Open the file in an editor (like Notepad, Notepad++), and add the following line:
  Set-Alias -name 'cpl' -value 'C:\The\Pathe\Where\The\Script\Is\Create-PlayLists.ps1'
  
  Next time you open a PowerShell terminal, you can call simply 'cpl C:\MyMusicLibrary'

  If you set the button in the commander to run the script, you can use it with a single click. It is VERY important to
    strictly use the following format in the Commander configuration:

    Execute command: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
    Icon file: <chose what you like>
    Start path: C:\Users\<YourUserID>\MusicLibraryTools\
    Parameters: C:\Users\<YourUserID>\MusicLibraryTools\Add-PlayLists.ps1 -w \"%P \"

.PARAMETER startPath
	The top folder where the script should start for music files. If non give, it will use the current directory.

.PARAMETER force
	If force enabled, it will create the playlist file even if there is one already in the album folder.

.PARAMETER delete
	If delete is enabled, it will delete the existing playlists from each album folder.
    
.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        0.9.1
  Author:         Geri
  Creation Date:  2024.05.23
  Purpose/Change: 2025.01.07 - Making ready for sharing

  

.EXAMPLE
  Create-PlayLists.ps1 C:\MyMusicLibrary
  
#>
#-------------------------------------------------------[Parameter Handling]-------------------------------------------------------
param (
    [Parameter(Mandatory=$false)]
    [string]$startPath,
    [switch]$force,
    [switch]$delete
)
#-----------------------------------------------------------[Functions]------------------------------------------------------------
function Start-Waiting {
    Write-Host -ForegroundColor Yellow "Press any key to continue..."
    while ($true) {
        if ($Host.UI.RawUI.KeyAvailable) {
            [void]$Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
            break
        }
    }   
}

function CreatePlaylistForDirectory {
    param (
        [string]$directoryPath
    )

    # Get the name of the current directory
    $currentDirName = Split-Path -Path $directoryPath -Leaf
	$fileName = $currentDirName
	# The fileName variable will be the name of the m3u file. My library is using the following structure:
	# Year - Album Title (some info) [maybe more info]. The goal is to have a file that looks like:
	# _Album Title.m3u
	# To achieve this, we will do some replacements, using regex. The result will be in the outputFileName variable
	$fileName = $fileName -replace '^\d\d\d\d.? - ' -replace '\[.*\]','' -replace '\(.*\)','' -replace '  ?$' #.Replace('[','').Replace(']','')
	#if(!$isVerbose){Write-Host "The new file name will be $fileName"}

    # Define the output file name, using the current directory name
    $outputFileName = "$directoryPath\_$fileName.m3u"
	
	# We gonna check if there is already an m3u file. If yes, we will create new only if the force switch is enabled.
	$isM3U = Get-ChildItem -LiteralPath $directoryPath | Where-Object {$_.Extension -eq ".m3u"}

	if(!$isM3U -or ($force)){
        # If 'delete' was reqested, we will remove the m3u files
		if($delete -and $isM3U){
			$m3uNames = Get-ChildItem -LiteralPath $directoryPath | Where-Object { 
				$_.Extension -eq ".m3u"  
			} | Select-Object -ExpandProperty Name
			foreach ($m3u in $m3uNames) {
				Remove-Item -LiteralPath $directoryPath\$m3u
				$Global:deletedPL++
			}			
		}
		# Find all matching files in the current directory (non-recursively) and store their names in a variable
		# If you want more file types to be found, add your line similar to what you see below
		$fileNames = Get-ChildItem -LiteralPath $directoryPath | Where-Object { 
			$_.Extension -eq ".flac" -or 
			$_.Extension -eq ".dsf" -or
			$_.Extension -eq ".ape" -or
			$_.Extension -eq ".dff" -or
			$_.Extension -eq ".mp3" -or
			$_.Extension -eq ".wav" -or
			$_.Extension -eq ".wv" 
		} | Select-Object -ExpandProperty Name
		
		# Write the filenames to the .m3u file if there are any files found in the current directory
		if ($fileNames) {
			$fileNames | Out-File -LiteralPath $outputFileName
			$Global:createdPL++
            $Global:albums++
			Write-Host "Created playlist in '$directoryPath' named $([char]27)[32m$([char]27)[7m '_$fileName.m3u'$([char]27)[0m " $createdPL #-ForegroundColor green 
			
		} else {
            # Now we check, if there is an iso file in the folder. If yes, that means that is also an album
            # We collect it for stats
            $isoNames = Get-ChildItem -LiteralPath $directoryPath | Where-Object {$_.Extension -eq ".iso"} | Select-Object -ExpandProperty Name
			if ($isoNames) {
                $Global:isoAlbums++
                $Global:albums++
            } else {
                Write-Verbose "There was no music files in $directoryPath folder..." 
			    $Global:skipped++
            }
		}
	} else {
		Write-Verbose "There was an m3u file  in $directoryPath folder already..."
		$Global:existing++
		$Global:skipped++
        $Global:albums++
	}
}

function TraverseDirectories {
    param (
        [string]$rootPath
    )

    # Create a playlist for the root directory
    CreatePlaylistForDirectory -directoryPath "$rootPath"

    # Recursively traverse each subdirectory and create playlists
    $directories = Get-ChildItem -LiteralPath $rootPath -Directory -Recurse
    foreach ($directory in $directories) {
		#if(!$isVerbose){Write-Host "Working on $directory"}
        CreatePlaylistForDirectory -directoryPath $directory.FullName
    }
}

#----------------------------------------------------------[Declarations]----------------------------------------------------------
$runTimeTXT = "Runtime: "
$startTime = Get-Date
$Global:createdPL = 0
$Global:deletedPL = 0
$Global:skipped = 0
$Global:existing = 0
$Global:albums = 0
$Global:isoAlbums = 0

#-----------------------------------------------------------[Main]------------------------------------------------------------
$isVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
if(!$isVerbose){Write-Host "Running..."}

# Next line is only for tshoting
# Write-Host "Working dir: $startPath" # Uncomment if needed

# Starting directory path, if no parameter was given, it takes the current dir
if(!$startPath){
	$startPath = $PWD
}

# For some reason "Unreal Commander" puts a space character at the end of the path, we have to cut it off if it is there...
$startPath = $startPath -replace ' ?$'

# Begin the traversal and playlist creation process
TraverseDirectories -rootPath $startPath

Write-Host "`nCreated"$Global:createdPL "new playlists," $Global:skipped "folders were skipped."
$allm3u=$Global:existing+$Global:createdPL
Write-Host "Number of existing playlists:" $Global:existing "`nNumber of total playlists:" $allm3u
if($Global:deletedPL -gt 0){Write-Host $Global:deletedPL"playlists were deleted."}
Write-Host "Number of total albums:" $Global:albums"," $Global:isoAlbums" are in ISO format."
$endTime = Get-Date
$runTime = [Math]::Round((New-TimeSpan -Start $startTime -end $endTime).totalseconds,2)
Write-Host $runTimeTXT$runTime "seconds."
Start-Waiting