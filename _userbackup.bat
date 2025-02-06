@echo off
setlocal

:: Define full path for the exclude file
set "EXCLUDEFILE=%~dp0exclude.txt"

:: Create temporary exclusion file by reading settings.json using PowerShell
powershell -Command "Get-Content '%~dp0settings.json' | ConvertFrom-Json | Select-Object -ExpandProperty excludeStrings | Out-File -Encoding ASCII '%EXCLUDEFILE%'"

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
set "backupDir=%~dp0%username%\Desktop_Backup"
if not exist "%backupDir%" mkdir "%backupDir%"

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
    if exist "C:\Users\%username%\%currentFolder%" (
        mkdir "%backupDir%\%currentFolder%" >nul 2>&1
        :: Use /exclude: with the full path (without extra quotes)
        xcopy /s /i /y "C:\Users\%username%\%currentFolder%" "%backupDir%\%currentFolder%" /exclude:%EXCLUDEFILE% >nul
        echo Copied %currentFolder% to backup
    ) else (
        echo No files found in %currentFolder%
    )
    set /a index+=1
    goto :CopyLoop
)

:RootFilesCopy
set "rootFilesDir=%backupDir%\Root_Files"
if not exist "%rootFilesDir%" mkdir "%rootFilesDir%"

@rem Copy typical document types from the user profile root
xcopy /y "C:\Users\%username%\*.docx" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.xlsx" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.pptx" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.pdf" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.doc" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.xls" "%rootFilesDir%" >nul
xcopy /y "C:\Users\%username%\*.ppt" "%rootFilesDir%" >nul

:PstFolderCheck
set "pstDir=%backupDir%\PST"
if not exist "%pstDir%" mkdir "%pstDir%"

:PstCopy
for /f "tokens=1" %%p in ('xcopy /d /y /s "C:\Users\%username%\*.pst" "%pstDir%" ^| findstr "File(s)"') do set pstCopied=%%p
if %pstCopied%==0 rmdir /s /q "%pstDir%"

:ReportSummary
for /f %%i in ('dir "%backupDir%" /s ^| find "File(s)"') do set filesCopied=%%i
echo Success: Files copied: %filesCopied%
echo .pst files found and copied: %pstCopied%

echo Starting compression...
:: Pass both username and backup option to the PowerShell script
PowerShell -executionpolicy bypass -command "& { . '%~dp0compress.ps1' '%username%' '%backupOption%' }"

:: Clean up the temporary exclusion file
del "%EXCLUDEFILE%"
pause
endlocal
