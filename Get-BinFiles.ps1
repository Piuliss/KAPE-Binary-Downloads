<#
.SYNOPSIS
    Download third-party binaries referenced in KAPE modules into the bin directory.

.DESCRIPTION
    This script searches KAPE module files (*.mkape) for lines beginning with "BinaryUrl:"
    and downloads EXE, PS1, and ZIP files referenced there. ZIPs are extracted into the bin
    directory and the archive is removed.

    The script will skip downloading any file that already exists in the destination bin folder.

.NOTES
    Author: eSecRPM (adapted)
    Modified: English comments + existence checks + error handling
#>

# Determine current directory and destination bin directory
$currentDirectory = (Resolve-Path ".").ProviderPath
$destinationDir = Join-Path $currentDirectory "bin"

# Ensure destination directory exists
if (-not (Test-Path -Path $destinationDir)) {
    New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
}

# Iterate all *.mkape files recursively and search for BinaryUrl lines
Get-ChildItem -Path $currentDirectory -Recurse -Filter *.mkape | ForEach-Object {
    $mkapeFile = $_.FullName

    Get-Content -Path $mkapeFile | ForEach-Object {
        $line = $_.Trim()

        # Match lines like: BinaryUrl: https://example.com/file.zip
        if ($line -match '^BinaryUrl:\s*(\S+)') {
            $URL = $Matches[1]
            $filename = Split-Path $URL -Leaf
            $extension = [IO.Path]::GetExtension($filename).TrimStart('.').ToLower()

            Write-Host "Found URL: $URL"

            $destinationFile = Join-Path $destinationDir $filename

            # Skip download if the file already exists
            if (Test-Path -Path $destinationFile) {
                Write-Host "File '$filename' already exists in the destination folder. Skipping download."
                return
            }

            try {
                Write-Host "Downloading $filename ..."
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($URL, $destinationFile)
                Write-Host "Downloaded: $destinationFile"

                # If ZIP, extract and remove the zip file
                if ($extension -eq 'zip') {
                    Write-Host "Extracting $filename ..."
                    Expand-Archive -Path $destinationFile -DestinationPath $destinationDir -Force
                    Remove-Item -Path $destinationFile -Force
                    Write-Host "Extracted and removed $filename"
                }
            }
            catch {
                Write-Warning "Failed to download or extract '$URL'. Error: $_"
                # Clean up any partially downloaded file
                if (Test-Path -Path $destinationFile) {
                    Remove-Item -Path $destinationFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

# Copy specific binaries from subfolders into the bin root if they exist
$copyMappings = @(
    @{ Source = Join-Path $destinationDir "win64\densityscout.exe"; Destination = $destinationDir },
    @{ Source = Join-Path $destinationDir "EvtxExplorer\EvtxECmd.exe"; Destination = $destinationDir },
    @{ Source = Join-Path $destinationDir "RegistryExplorer\RECmd.exe"; Destination = $destinationDir },
    @{ Source = Join-Path $destinationDir "ShellBagsExplorer\SBECmd.exe"; Destination = $destinationDir },
    @{ Source = Join-Path $destinationDir "sqlite-tools-win32-x86-3270200\sqlite3.exe"; Destination = $destinationDir }
)

foreach ($map in $copyMappings) {
    if (Test-Path -Path $map.Source) {
        try {
            Copy-Item -Path $map.Source -Destination $map.Destination -Force
            Write-Host "Copied $(Split-Path $map.Source -Leaf) to bin root."
        }
        catch {
            Write-Warning "Failed to copy '$($map.Source)'. Error: $_"
        }
    }
    else {
        Write-Host "Source '$($map.Source)' not found. Skipping."
    }
}