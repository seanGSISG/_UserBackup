@echo off
setlocal

echo ===========================================
echo Starting User Backup Process...
echo ===========================================

:: Define full path for the exclude file
set "EXCLUDEFILE=%~dp0exclude.txt"

echo Generating exclusion list from settings.json...
:: Create temporary exclusion file by reading settings.json using PowerShell
powershell -Command "Get-Content '%~dp0settings.json' | ConvertFrom-Json | Select-Object -ExpandProperty excludeStrings | Out-File -Encoding ASCII '%EXCLUDEFILE%'"
echo Exclusion file created: %EXCLUDEFILE%

set "filesCopied=0"
set "pstCopied=0"

:UsernameCheck
set /P username=Enter Username: 
if exist "C:\Users\%username%" (
    goto :BackupSelection
) else (
    echo Username does not exist. Please try again.
    goto :UsernameCheck
)

:BackupSelection
set /P backupOption=Choose backup server: (B)oulder or (H)awaii: 
:: Normalize to the first character (upper-case)
set backupOption=%backupOption:~0,1%
if /I "%backupOption%"=="B" (
    echo Boulder Server selected.
) else if /I "%backupOption%"=="H" (
    echo Hawaii Server selected.
) else (
    echo Invalid choice. Defaulting to Boulder Server.
    set backupOption=B
)

:BackupPreparation
echo Creating backup directories...
set "backupDir=%~dp0%username%\Desktop_Backup"
if not exist "%backupDir%" mkdir "%backupDir%"
echo Backup directory set to: %backupDir%

set "folders[0]=Desktop"
set "folders[1]=Documents"
set "folders[2]=Downloads"
set "folders[3]=Favorites"
set "folders[4]=Links"
set "folders[5]=Pictures"
set "folders[6]=Videos"

set "index=0"
:CopyLoop
if defined folders[%index%] (
    call set "currentFolder=%%folders[%index%]%%"
    echo Processing folder: %currentFolder%
    if exist "C:\Users\%username%\%currentFolder%" (
        mkdir "%backupDir%\%currentFolder%" >nul 2>&1
        echo Copying %currentFolder%...
        xcopy /s /i /y "C:\Users\%username%\%currentFolder%" "%backupDir%\%currentFolder%" /exclude:%EXCLUDEFILE% >nul
        echo Copied %currentFolder% to backup.
    ) else (
        echo No files found in %currentFolder%.
    )
    set /a index+=1
    goto :CopyLoop
)

:RootFilesCopy
echo Copying document files from the root...
set "rootFilesDir=%backupDir%\Root_Files"
if not exist "%rootFilesDir%" mkdir "%rootFilesDir%"
xcopy /y "C:\Users\%username%\*.docx" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.xlsx" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.pptx" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.pdf" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.doc" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.xls" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.ppt" "%rootFilesDir%" >nul
echo Document files copied.

:PstFolderCheck
set "pstDir=%backupDir%\PST"
if not exist "%pstDir%" mkdir "%pstDir%"

:PstCopy
echo Searching for PST files...
for /f "tokens=1" %%p in ('xcopy /d /y /s "C:\Users\%username%\*.pst" "%pstDir%" ^| findstr "File(s)"') do set pstCopied=%%p
if %pstCopied%==0 (
    echo No PST files found, removing PST folder...
    rmdir /s /q "%pstDir%"
) else (
    echo PST files found and copied: %pstCopied%
)

:ReportSummary
echo -------------------------------------------
for /f %%i in ('dir "%backupDir%" /s ^| find "File(s)"') do set filesCopied=%%i
echo Backup Summary:
echo Files copied: %filesCopied%
echo PST files copied: %pstCopied%
echo -------------------------------------------

echo Starting compression process...
:: Pass both username and backup option to the PowerShell script
PowerShell -executionpolicy bypass -command "& { . '%~dp0compress.ps1' '%username%' '%backupOption%' }"

echo Cleaning up temporary files...
:: Clean up the temporary exclusion file
del "%EXCLUDEFILE%"
echo Backup process completed.
pause
endlocal
