@echo off
setlocal enabledelayedexpansion

:: ** Enhanced User Backup Script (version 2.0) **
:: This script backs up a user profile from C:\Users$Username] 
:: and compresses it using 7-Zip before copying to a remote server.

:: ** Configuration Settings ** 
set "settingsFile=settings.json"
set "logFile=%TEMP%\user_backup_log_%DATE%-%TIME%.txt"

:: ** Backup Directories **
set "backupDir=[ScriptFolder]\%username%"
set "rootFilesDir=%backupDir%\Root_Files"
set "pstDir=%backupDir%\PST"

:: ** Exclude Folders (read from settings.json) **
set "excludeStrings=YOUR COMPANY NAME FOR SHAREPOINT SYNCS|OneDrive"

:: ** Initialize Logging **
echo Starting backup process at %time% > "%logFile%"
if not exist "%logFile%" (
    echo Failed to create log file. exiting...
    pause
    exit /b 1
)

:: ** Validate Required Tools and Dependencies **
where robocopy >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Robocopy is not found. Please ensure it is installed (it comes with Windows).
    pause
    exit /b 1
)

:: ** Read Username and Backup Option from Input **
set /p "username=Enter the username to backup: "
set /p "backupOption=Select backup server (B for Boulder, H for Hawaii): "

:: ** Validate Input Parameters **
if not defined username (
    echo No username provided. Exiting...
    pause
    exit /b 1
)

if "%backupOption%" not in ("B","H") (
    echo Invalid backup option. Please enter B or H.
    pause
    exit /b 1
)

:: ** Function to Copy Folders **
:CopyFolder "%%currentFolder%%"
echo Copying files from %%currentFolder%%
robocopy "C:\Users\%username%\%%currentFolder%%" "%backupDir%\%%currentFolder%%" /mov /minfreespace:10MB /log+:"%logFile%" >nul
if %ERRORLEVEL% neq 0 (
    echo Failed to copy files from %%currentFolder%%
    exit /b 1
)
goto :EOF

:: ** Function to Copy Root Files and Folders **
:CopyRootFiles
echo Copying root files...
robocopy "C:\Users\%username%" "%rootFilesDir%" /mov /minfreespace:10MB /xf *.7z *.log *.tmp /log+:"%logFile%" >nul
if %ERRORLEVEL% neq 0 (
    echo Failed to copy root files.
    exit /b 1
)
goto :EOF

:: ** Function to Copy PST Files **
:CopyPSTFiles
echo Copying PST files...
robocopy "C:\Users\%username%\AppData\Local\Microsoft\Outlook" "%pstDir%" /mov /minfreespace:10MB /xf *. pst /log+:"%logFile%" >nul
if %ERRORLEVEL% neq 0 (
    echo Failed to copy PST files.
    exit /b 1
)
goto :EOF

:: ** Main Backup Process **
echo *********************************************************************************
echo Starting backup for user "%username%"
echo ********************************************************************************* >> "%logFile%"

:: ** Create Backup Directory if it doesn't exist **
if not exist "%backupDir%" (
    echo Creating backup directory "%backupDir%"
    mkdir "%backupDir%" || (echo Failed to create backup directory & exit /b 1)
)

:: ** Copy Key Folders and Files **
call :CopyFolder "Documents"
call :CopyFolder "Downloads"
call :CopyFolder "Pictures"
call :CopyFolder "Videos"

call :CopyRootFiles
call :CopyPSTFiles

:: ** Generate Temporary Exclusion File (if needed) **
if exist "%settingsFile%" (
    echo Creating exclusion file...
    rem This is a placeholder for your actual logic to generate the exclusion list.
    echo Your code here...
) else (
    echo Settings file not found. Using default settings.
)

:: ** Compress Backup Data and Copy to Remote Server (call compress.ps1) **
echo *********************************************************************************
echo Starting compression and remote backup
echo ********************************************************************************* >> "%logFile%"

powershell -file compress.ps1 -userName "%username%" -backupOption "%backupOption%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Compression or remote backup failed.
    pause
    exit /b 1
)

:: ** Cleanup Temporary Files (Optional) **
del /f /s /q "*.tmp" >> "%logFile%" 2>&1

:: ** Success Message **
echo *********************************************************************************
echo Backup process completed successfully!
echo Log file: "%logFile%"
echo *********************************************************************************
pause
exit /b 0

:: ** Error Handling and Logging Examples (Placeholders) **
:ErrorHandler
echo An error occurred at line %ERRORLEVEL%: %_
goto :EOF

:: ** End of Script **
