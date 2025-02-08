param (
    [string]$userName,
    [string]$backupOption
)

# Verify the username parameter
if (-not $userName) {
    Write-Host "No username provided. Exiting..."
    exit 1
}

# Define log file in the script's directory
$scriptDir = Split-Path -Parent $PSCommandPath
$logFile = Join-Path -Path $scriptDir -ChildPath "compression_log.txt"

if (-not (Test-Path $logFile)) {
    Write-Host "Log file path: $logFile"
}

function Write-Log {
    param ([string]$message)
    Write-Host $message
    $message | Out-File -Append -FilePath $logFile
}

Write-Log "Starting compression for user '$userName'..."

# Get the directory where this script is located
$ScriptPath = $PSCommandPath
$dir = Split-Path $ScriptPath

# Read settings.json from the script directory
$settingsFile = Join-Path -Path $dir -ChildPath "settings.json"
if (-not (Test-Path $settingsFile)) {
    Write-Log "Settings file not found at $settingsFile. Exiting..."
    exit 1
}
$settings = Get-Content $settingsFile | ConvertFrom-Json

# Define the user's folder and the Desktop_Backup folder
$userFile = Join-Path -Path $dir -ChildPath $userName
$desktopFiles = Join-Path -Path $userFile -ChildPath "Desktop_Backup"

# Ensure the Desktop_Backup folder exists before proceeding
if (-not (Test-Path $desktopFiles)) {
    Write-Log "Desktop_Backup folder for user '$userName' does not exist. Exiting..."
    exit 1
}

# Define the path to 7-Zip executable
$sevenZip = "C:\Program Files\7-Zip\7z.exe"

# Check for 7-Zip BEFORE archiving
if (-not (Test-Path $sevenZip)) {
    Write-Log "7-Zip not found at $sevenZip. Attempting installation via Chocolatey..."
    $chocoPath = Get-Command choco.exe -ErrorAction SilentlyContinue
    if (-not $chocoPath) {
        Write-Log "Chocolatey is not installed. Please install Chocolatey and re-run the script."
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
        Write-Log "7-Zip installation failed after waiting for $maxWait seconds. Exiting..."
        exit 1
    } else {
        Write-Log "7-Zip successfully installed."
    }
}

# Capitalize the first two letters of the username for folder/archive naming
if ($userName.Length -ge 2) {
    $userFolderName = $userName.Substring(0,2).ToUpper() + $userName.Substring(2)
} else {
    $userFolderName = $userName.ToUpper()
}

# Define the archive file path as Username_Laptop.7z inside the user's folder
$archiveFile = Join-Path -Path $userFile -ChildPath ("{0}_Laptop.7z" -f $userFolderName)

# Build the 7-Zip compression command using options from settings.json and enable multi-threading
$sevenZipOptions = $settings.sevenZipOptions
$compressCommand = "& `"$sevenZip`" a -t$($sevenZipOptions.archiveFormat) -$($sevenZipOptions.compressionLevel) -m0=$($sevenZipOptions.compressionMethod) -md=$($sevenZipOptions.dictionarySize) mfb=$($sevenZipOptions.wordSize) -ms=$($sevenZipOptions.solidMode) -mmt=4 `"$archiveFile`" `"$desktopFiles`""
Write-Log "Running the 7-Zip command:"
Write-Log $compressCommand

try {
    Invoke-Expression $compressCommand
    if (-not (Test-Path $archiveFile)) {
        throw "7-Zip failed to create the .7z archive."
    }
    Write-Log "Compression completed successfully for user '$userName'. Archive created at '$archiveFile'."
} catch {
    Write-Log "Error during compression: $_"
    exit 1
}

# Determine backup server based on the backupOption parameter using settings from JSON
switch ($backupOption.ToUpper()) {
    "B" { $backupServer = $settings.backupLocations.Boulder }
    "H" { $backupServer = $settings.backupLocations.Hawaii }
    default { Write-Log "Invalid backup option provided. Skipping remote backup."; exit 1 }
}

# Build the destination folder path on the remote server (folder named after the user)
$destinationFolder = Join-Path -Path $backupServer -ChildPath $userFolderName

# Create the destination folder if it does not exist
if (-not (Test-Path $destinationFolder)) {
    Write-Log "Destination folder '$destinationFolder' does not exist. Creating it..."
    try {
        New-Item -Path $destinationFolder -ItemType Directory -Force | Out-Null
        Write-Log "Folder '$destinationFolder' created successfully."
    } catch {
        Write-Log "Failed to create folder '$destinationFolder': $_"
        exit 1
    }
} else {
    Write-Log "Destination folder '$destinationFolder' already exists."
}

# Copy the .7z archive to the destination folder
try {
    Copy-Item -Path $archiveFile -Destination $destinationFolder -Force
    Write-Log "Archive '$archiveFile' successfully copied to '$destinationFolder'."
} catch {
    Write-Log "Error copying the archive: $_"
    exit 1
}

exit 0
