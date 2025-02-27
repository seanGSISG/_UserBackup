param (
    [Parameter(Mandatory=$true)]
    [string]$userName,
    [Parameter(Mandatory=$true)]
    [string]$backupOption
)

# Verify the username parameter
if (-not $userName) {
    Write-Host "No username provided. Exiting..."
    exit 1
}

# Get the directory where this script is located
$ScriptPath = $PSCommandPath
$dir = Split-Path $ScriptPath

# Read settings.json from the script directory
$settingsFile = Join-Path -Path $dir -ChildPath "settings.json"
if (-not (Test-Path $settingsFile)) {
    Write-Host "Settings file not found at $settingsFile. Exiting..."
    exit 1
}
$settings = Get-Content $settingsFile | ConvertFrom-Json

# Define the user's folder and the Desktop_Backup folder
$userFile = Join-Path -Path $dir -ChildPath $userName
$desktopFiles = Join-Path -Path $userFile -ChildPath "Desktop_Backup"

# Ensure the Desktop_Backup folder exists before proceeding
if (-not (Test-Path $desktopFiles)) {
    Write-Host "Desktop_Backup folder for user '$userName' does not exist. Exiting..."
    exit 1
}

# Capitalize the first two letters of the username for folder/archive naming
if ($userName.Length -ge 2) {
    $userFolderName = $userName.Substring(0,2).ToUpper() + $userName.Substring(2)
} else {
    $userFolderName = $userName.ToUpper()
}

# Define the archive file path as Username_Laptop.7z inside the user's folder
$archiveFile = Join-Path -Path $userFile -ChildPath ("{0}_Laptop.7z" -f $userFolderName)

# Set up logging in the same folder as the archive file
$archiveFolder = Split-Path $archiveFile
$logFile = Join-Path -Path $archiveFolder -ChildPath "compression_log.txt"

# Clear any existing log file so you start fresh
if (Test-Path $logFile) { Remove-Item $logFile -Force }

# Improved logging function with timestamps and log levels
function Write-Log {
    param (
         [string]$message,
         [string]$level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$level] $message"
    Write-Host $logEntry
    Add-Content -Path $logFile -Value $logEntry
}

Write-Log "Starting compression for user '$userName'..."

# Define the path to 7-Zip executable
$sevenZip = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $sevenZip)) {
    Write-Log "7-Zip not found at $sevenZip. Attempting installation via Chocolatey..." "WARN"
    $chocoPath = Get-Command choco.exe -ErrorAction SilentlyContinue
    if (-not $chocoPath) {
         Write-Log "Chocolatey is not installed. Please install Chocolatey and re-run the script." "ERROR"
         exit 1
    }
    & choco install 7zip -y | Out-Null
    $maxWait = 60
    $waited = 0
    while (-not (Test-Path $sevenZip) -and $waited -lt $maxWait) {
         Start-Sleep -Seconds 5
         $waited += 5
    }
    if (-not (Test-Path $sevenZip)) {
         Write-Log "7-Zip installation failed after waiting for $maxWait seconds. Exiting..." "ERROR"
         exit 1
    } else {
         Write-Log "7-Zip successfully installed."
    }
}

# Build the 7-Zip compression command using options from settings.json
Write-Log "Building 7-Zip compression command..."
$sevenZipOptions = $settings.sevenZipOptions
$compressCommand = "& `"$sevenZip`" a -t$($sevenZipOptions.archiveFormat) -$($sevenZipOptions.compressionLevel) -m0=$($sevenZipOptions.compressionMethod) -md=$($sevenZipOptions.dictionarySize) -mfb=$($sevenZipOptions.wordSize) -ms=$($sevenZipOptions.solidMode) -mmt=$($sevenZipOptions.multiThreading) `"$archiveFile`" `"$desktopFiles`""
Write-Log "7-Zip command: $compressCommand"

# Start the compression process and measure elapsed time
Write-Log "Starting compression process..."
$compressionTimer = [System.Diagnostics.Stopwatch]::StartNew()
try {
    Invoke-Expression $compressCommand
    $compressionTimer.Stop()
    if (-not (Test-Path $archiveFile)) {
        throw "7-Zip failed to create the .7z archive."
    }
    Write-Log "Compression completed successfully for user '$userName'. Archive created at '$archiveFile'."
    Write-Log "Compression took $($compressionTimer.Elapsed.ToString())."
} catch {
    Write-Log "Error during compression: $_" "ERROR"
    exit 1
}

# Determine backup server based on the backupOption parameter using settings from JSON
switch ($backupOption.ToUpper()) {
    "B" { $backupServer = $settings.backupLocations.Boulder }
    "H" { $backupServer = $settings.backupLocations.Hawaii }
    default { Write-Log "Invalid backup option provided. Skipping remote backup." "ERROR"; exit 1 }
}

Write-Log "Remote backup server determined: $backupServer"

# Build the destination folder path on the remote server (folder named after the user)
$destinationFolder = Join-Path -Path $backupServer -ChildPath $userFolderName
Write-Log "Destination folder for remote backup: $destinationFolder"

# Create the destination folder if it does not exist
if (-not (Test-Path $destinationFolder)) {
    Write-Log "Destination folder does not exist. Creating it..."
    try {
        New-Item -Path $destinationFolder -ItemType Directory -Force | Out-Null
        Write-Log "Destination folder created successfully."
    } catch {
        Write-Log "Failed to create destination folder: $_" "ERROR"
        exit 1
    }
} else {
    Write-Log "Destination folder already exists."
}

# Use Robocopy to transfer the .7z archive with progress output and ETA.
# Since Robocopy operates on directories, extract the source directory and file name.
$archiveDir = Split-Path $archiveFile
$archiveName = Split-Path $archiveFile -Leaf

# Build robocopy argument list:
$robocopyArgs = @(
    $archiveDir,          # Source directory
    $destinationFolder,   # Destination directory
    $archiveName,         # File filter (the archive file)
    "/NP",                # No progress percentage in robocopy's output (keeps output cleaner)
    "/ETA",               # Show estimated time of arrival
    "/NFL",               # No file list
    "/NDL"                # No directory list
)

Write-Log "Starting file transfer using Robocopy..."
Write-Log "Running: robocopy `"$archiveDir`" `"$destinationFolder`" `"$archiveName`" /NP /ETA /NFL /NDL"

# Start the file transfer process and measure elapsed time
$fileTransferTimer = [System.Diagnostics.Stopwatch]::StartNew()
$robocopyProcess = Start-Process -FilePath "robocopy" -ArgumentList $robocopyArgs -NoNewWindow -Wait -PassThru
$fileTransferTimer.Stop()

# Robocopy returns an exit code; codes below 8 are generally considered successful.
if ($robocopyProcess.ExitCode -ge 8) {
    Write-Log "Robocopy encountered an error. Exit code: $($robocopyProcess.ExitCode)" "ERROR"
    exit 1
} else {
    Write-Log "File transfer completed successfully using Robocopy."
    Write-Log "File transfer took $($fileTransferTimer.Elapsed.ToString())."
}

Write-Log "Compression and backup process completed successfully."
exit 0
