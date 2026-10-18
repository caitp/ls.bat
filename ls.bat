@echo off

setlocal DisableDelayedExpansion
call :setESC

where.exe ls.exe >nul 2>&1
if not errorlevel 1 (
    ls.exe --color=if-tty %*
    exit /b %ERRORLEVEL%
)

set "SHOWALL=0"
set "LONG=0"
set "ONE=0"
set "TARGET=."
set "CONCOLS="
for /f "tokens=2" %%C in ('mode con ^| findstr /i "Columns:"') do set "CONCOLS=%%C"
if not defined CONCOLS set "CONCOLS=80"

:args
if "%~1"=="" goto run
if "%~1"=="--" (
    shift
    goto paths
)

set "ARG=%~1"
if not "%ARG:~0,1%"=="-" (
    call :setTarget "%~1"
    shift
    goto args
)

set "OPT=%ARG:~1%"
shift

:parseFlags
if not defined OPT goto args

set "FLAG=%OPT:~0,1%"
set "OPT=%OPT:~1%"

if "%FLAG%"=="a" (
    set "SHOWALL=1"
    goto parseFlags
)
if "%FLAG%"=="l" (
    set "LONG=1"
    goto parseFlags
)
if /i "%FLAG%"=="1" (
    set "ONE=1"
    goto parseFlags
)
if "%FLAG%"=="C" (
    set "COLUMNS=1"
    goto parseFlags
)
if "%FLAG%"=="x" (
    set "COLUMNS=0"
    goto parseFlags
)

echo ls: unknown option -%FLAG%
exit /b 2

set "TARGET=%~1"
shift
goto args

:paths
echo "Testing path '%~1'"
if "%~1"=="" goto run
call :setTarget "%~1"
shift
goto paths

:run
if not exist "%TARGET%\" if not exist "%TARGET%" (
    echo ls: cannot access "%TARGET%"
    exit /b 1
)

if "%LONG"=="0" if "%COLUMNS%"=="1" goto columnListing

if "%LONG%"=="1" (
    set "MAXWIDTH=4"
    if "%SHOWALL%"=="1" (
        for /f "delims=" %%F in ('dir /b /a "%TARGET%" 2^>nul') do call :measureSize "%%F"
    ) else (
        for /f "delims=" %%F in ('dir /b /a:-h "%TARGET%" 2^>nul') do call :measureSize "%%F"
    )

    echo Attributes  Modified              Size  Name
    if "%SHOWALL%"=="1" (
        for /f "delims=" %%F in ('dir /b /a "%TARGET%" 2^>nul') do call :showLong "%%F"
    ) else (
        for /f "delims=" %%F in ('dir /b /a:-h "%TARGET%" 2^>nul') do call :showLong "%%F"
    )
    exit /b
)

if "%SHOWALL%"=="1" (
    for /f "delims=" %%F in ('dir /b /a "%TARGET%" 2^>nul') do call :show "%%F"
) else (
    for /f "delims=" %%F in ('dir /b /a:-h "%TARGET%" 2^>nul') do call :show "%%F"
)
exit /b

:show
set "ITEM=%~1"

if exist "%TARGET%\%ITEM%\" (
    echo %ESC%[94m%ITEM%%ESC%[0m
    exit /b
)

if /i "%~x1"==".exe" goto executable
if /i "%~x1"==".com" goto executable
if /i "%~x1"==".bat" goto executable
if /i "%~x1"==".cmd" goto executable

echo %ITEM%
exit /b

:executable
echo %ESC%[92m%ITEM%%ESC%[0m
exit /b

:setESC
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
    set "ESC=%%b"
    exit /B 0
)
exit /B 0

:showLong
set "ITEM=%~1"

if exist "%TARGET%\%ITEM%\" (
    for %%I in ("%TARGET%\%ITEM%") do (
        set "ATTR=%%~aI"
        set "MODIFIED=%%~tI"
        set "SIZE=                                %%~zI"
    )
    call :printLong 94
    exit /b
)

if /i "%~x1"==".exe" goto longExecutable
if /i "%~x1"==".com" goto longExecutable
if /i "%~x1"==".bat" goto longExecutable
if /i "%~x1"==".cmd" goto longExecutable

for %%I in ("%TARGET%\%ITEM%") do (
    set "ATTR=%%~aI"
    set "MODIFIED=%%~tI"
    set "SIZE=            %%~zI"
)
call :printLong 0
exit /b

:longExecutable
for %%I in ("%TARGET%\%ITEM%") do (
    set "ATTR=%%~aI"
    set "MODIFIED=%%~tI"
    set "SIZE=            %%~zI"
)
call :printLong 92
exit /b

:printLong
call echo %%ATTR%%  %%MODIFIED%%  %%SIZE:~-%MAXWIDTH%%%  %%ESC%%[%%~1m%%ITEM%%%%ESC%%[0m
exit /b

:measureSize
if exist "%TARGET%\%~1\" (
    for %%I in ("%TARGET%\%~1") do call :checkSize "%%~zI"
) else (
    for %%I in ("%TARGET%\%~1") do call :checkSize "%%~zI"
)
exit /b

:checkSize
set "S=%~1"
set "LEN=0"

:countSizeChars
if not defined S goto sizeCounted
set "S=%S:~1%"
set /a LEN+=1
goto countSizeChars

:sizeCounted
if %LEN% GTR %MAXWIDTH% set "MAXWIDTH=%LEN%"
exit /b

:columnListing
set "CONCOLS="
for /f "tokens=2" %%C in ('mode con ^| findstr /i "Columns:"') do set "CONCOLS=%%C"
if not defined CONCOLS set "CONCOLS=80"

set "LIST=%TEMP%\ls-%RANDOM%-%RANDOM%.tmp"
if "%SHOWALL%"=="1" (
    dir /b /a "%TARGET%" >"%LIST%" 2>nul
) else (
    dir /b /a:-h "%TARGET%" >"%LIST%" 2>nul
)

set "COUNT=0"
set "MAXNAME=0"
for /f "usebackq delims=" %%F in ("%LIST%") do (
    set /a COUNT+=1
    call :measureName "%%F"
)
if "%COUNT%"=="0" (
    del "%LIST%" 2>nul
    exit /b
)

rem Use the longest name to choose how many columns fit.
set /a CELL=MAXNAME+2
set /a COLS=CONCOLS/CELL
if %COLS% LSS 1 set "COLS=1"
if %COLS% GTR %COUNT% set "COLS=%COUNT%"

set /a ROWS=(COUNT+COLS-1)/COLS

rem Measure each column's own maximum name width.
for /l %%C in (0,1,%COLS%-1) do set "W%%C=0"
for /l %%C in (0,1,%COLS%-1) do call :measureColumn %%C

rem Print rows, reading down each column.
for /l %%R in (0,1,%ROWS%-1) do call :printRow %%R

del "%LIST%" 2>nul
exit /b

:measureName
set "S=%~1"
set "LEN=0"
:measureNameLoop
if not defined S goto measureNameDone
set "S=%S:~1%"
set /a LEN+=1
goto measureNameLoop
:measureNameDone
if %LEN% GTR %MAXNAME% set "MAXNAME=%LEN%"
exit /b

:measureColumn
set "COL=%~1"
set "WIDTH=0"
for /l %%R in (0,1,%ROWS%-1) do (
    set /a INDEX=COL*ROWS+%%R
    call :readItem !INDEX!
    if defined ITEM call :getNameLength
)
set "W%COL%=%WIDTH%"
exit /b

:getNameLength
set "S=%ITEM%"
set "LEN=0"
:getNameLengthLoop
if not defined S goto getNameLengthDone
set "S=%S:~1%"
set /a LEN+=1
goto getNameLengthLoop
:getNameLengthDone
if %LEN% GTR %WIDTH% set "WIDTH=%LEN%"
exit /b

:printRow
set "ROW=%~1"
for /l %%C in (0,1,%COLS%-1) do (
    set /a INDEX=%%C*ROWS+ROW
    call :readItem !INDEX!
    if defined ITEM call :printItem %%C
)
echo.
exit /b

:readItem
set "ITEM="
set /a SKIP=%~1
for /f "usebackq skip=%SKIP% delims=" %%A in ("%LIST%") do (
    if not defined ITEM set "ITEM=%%A"
)
exit /b

:printItem
set "PAD=                                "
call set "WIDTH=%%W%~1%%"
set "PADDED=%ITEM%%PAD%"
call echo %ESC%[94m%PADDED:~0,%WIDTH%%% %ESC%[0m
exit /b

:setTarget
set "TARGET=%~1"

rem Expand only "~" and "~/..." or "~\..." to the current user's profile.
if "%TARGET%"=="~" (
  set "TARGET=%USERPROFILE%"
  echo "set target to %TARGET%"
)
if "%TARGET:~0,2%"=="~/" set "TARGET=%USERPROFILE%\%TARGET:~2%"
if "%TARGET:~0,2%"=="~\" set "TARGET=%USERPROFILE%\%TARGET:~2%"

rem Convert Unix-style separators to Windows separators.
set "TARGET=%TARGET:/=\%"
exit /b