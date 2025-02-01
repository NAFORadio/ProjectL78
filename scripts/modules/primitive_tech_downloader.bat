@echo off
setlocal EnableDelayedExpansion

:: ANSI color codes for Windows
set "GREEN=[32m"
set "YELLOW=[33m"
set "RED=[31m"
set "NC=[0m"

:: Enable ANSI escape sequences
reg query HKCU\Console /v VirtualTerminalLevel >nul 2>&1
if %ERRORLEVEL% EQU 1 (
    reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f
)

cls

:: Display NAFO Radio banner
echo ===============================================================
echo  _   _    _    _____ ___    ____          _ _       
echo ^| \ ^| ^|  / \  ^|  ___|_ _^|  ^|  _ \ __ _ __^| (_) ___  
echo ^|  \^| ^| / _ \ ^| ^|_   ^| ^|   ^| ^|_) / _` / _` ^| ^| / _ \ 
echo ^| ^|\  ^|/ ___ \^|  _^|  ^| ^|   ^|  _ ^< (_^| (_^| ^| ^| (_) ^|
echo ^|_^| \_/_/   \_\_^|   ^|___^|  ^|_^| \_\__,_\__,_^|_^|\___/ 
echo.    
echo     Knowledge Acquisition Department
echo     Offline Content Archive Division
echo ===============================================================

:: Show Windows warning
echo %YELLOW%WARNING: Windows is NOT recommended for end times computing!%NC%
echo Consider switching to a low-power Linux device.
echo.
set /p "continue=Continue anyway? (yes/no): "
if /i not "%continue%"=="yes" exit /b

:: Set paths
set "STORAGE_DIR=%USERPROFILE%\Desktop\Primitive_Technology"
set "VIDEOS_DIR=%STORAGE_DIR%\Videos"
set "LOG_FILE=%STORAGE_DIR%\logs\primitive_tech_download.log"

:: Create directories
if not exist "%STORAGE_DIR%" mkdir "%STORAGE_DIR%"
if not exist "%VIDEOS_DIR%" mkdir "%VIDEOS_DIR%"
if not exist "%STORAGE_DIR%\logs" mkdir "%STORAGE_DIR%\logs"

:: Check prerequisites
call :check_prerequisites
if errorlevel 1 exit /b

:menu
cls
echo %YELLOW%What would you like to do?%NC%
echo 1. Download videos and create index
echo 2. Create/update index only
echo 3. Generate/update thumbnails only
echo 4. Verify and fix video index
echo q. Quit
set /p "choice=Enter your choice (1-4 or q): "

if "%choice%"=="1" (
    call :download_videos
    call :generate_thumbnails
    call :create_index
) else if "%choice%"=="2" (
    call :create_index
) else if "%choice%"=="3" (
    call :generate_thumbnails
) else if "%choice%"=="4" (
    call :verify_index
) else if /i "%choice%"=="q" (
    exit /b
) else (
    echo %RED%Invalid choice%NC%
    timeout /t 2 >nul
    goto :menu
)

goto :menu

:check_prerequisites
echo Checking prerequisites...

:: Check for Chocolatey
where choco >nul 2>&1
if errorlevel 1 (
    echo Installing Chocolatey...
    @powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    if errorlevel 1 (
        echo %RED%Failed to install Chocolatey%NC%
        exit /b 1
    )
)

:: Install required packages
choco install -y python ffmpeg wget git >nul 2>&1
pip install --upgrade yt-dlp >nul 2>&1

echo %GREEN%Prerequisites installed successfully%NC%
exit /b 0

:download_videos
echo %YELLOW%Downloading videos...%NC%
yt-dlp --format "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best[height<=720]" ^
    --output "%VIDEOS_DIR%\%%(title)s.%%(ext)s" ^
    --write-description ^
    --write-thumbnail ^
    --ignore-errors ^
    --continue ^
    --retries 10 ^
    --force-ipv4 ^
    "https://www.youtube.com/@primitivetechnology9550/videos"
exit /b

:generate_thumbnails
echo %YELLOW%Generating thumbnails...%NC%
for %%F in ("%VIDEOS_DIR%\*.mp4") do (
    if not exist "%%~dpnF.jpg" (
        ffmpeg -i "%%F" -ss 00:00:02 -frames:v 1 -vf "scale=640:-1" "%%~dpnF.jpg" -y >nul 2>&1
        echo Generated thumbnail for: %%~nxF
    )
)
exit /b

:create_index
echo %YELLOW%Creating video index...%NC%

:: Count total videos
set "video_count=0"
for %%F in ("%VIDEOS_DIR%\*.mp4") do set /a "video_count+=1"
echo Found !video_count! videos to index

:: Get current date and time
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "current_date=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2% %datetime:~8,2%:%datetime:~10,2%"

:: Create index.html header
(
    echo ^<!DOCTYPE html^>
    echo ^<html^>
    echo ^<head^>
    echo     ^<title^>Primitive Technology Archive^</title^>
    echo     ^<style^>
    echo         :root {
    echo             --matrix-green: #00ff41;
    echo             --matrix-dark: #0a0a0a;
    echo             --matrix-darker: #050505;
    echo             --text-color: #cccccc;
    echo         }
    echo         body {
    echo             font-family: 'Courier New', monospace;
    echo             background-color: var(--matrix-darker^);
    echo             color: var(--text-color^);
    echo             margin: 0;
    echo             padding: 20px;
    echo             line-height: 1.6;
    echo         }
    echo         .header {
    echo             text-align: center;
    echo             padding: 20px;
    echo             border-bottom: 1px solid var(--matrix-green^);
    echo             margin-bottom: 30px;
    echo         }
    echo         h1 {
    echo             color: var(--matrix-green^);
    echo             text-shadow: 0 0 10px var(--matrix-green^);
    echo             margin-bottom: 10px;
    echo         }
    echo         .stats {
    echo             color: var(--matrix-green^);
    echo             font-size: 0.9em;
    echo             margin-bottom: 20px;
    echo         }
    echo         .video-grid {
    echo             display: grid;
    echo             grid-template-columns: repeat(auto-fill, minmax(300px, 1fr^)^);
    echo             gap: 20px;
    echo             padding: 20px;
    echo         }
    echo         .video-card {
    echo             background-color: var(--matrix-dark^);
    echo             border: 1px solid var(--matrix-green^);
    echo             border-radius: 5px;
    echo             overflow: hidden;
    echo             transition: transform 0.2s, box-shadow 0.2s;
    echo         }
    echo         .video-card:hover {
    echo             transform: translateY(-5px^);
    echo             box-shadow: 0 0 15px var(--matrix-green^);
    echo         }
    echo         .thumbnail {
    echo             width: 100%%;
    echo             height: 169px;
    echo             object-fit: cover;
    echo             border-bottom: 1px solid var(--matrix-green^);
    echo         }
    echo         .video-info {
    echo             padding: 15px;
    echo         }
    echo         .video-title {
    echo             color: var(--matrix-green^);
    echo             font-weight: bold;
    echo             margin-bottom: 10px;
    echo             font-size: 0.9em;
    echo         }
    echo         .video-desc {
    echo             font-size: 0.8em;
    echo             max-height: 100px;
    echo             overflow-y: auto;
    echo         }
    echo         .video-link {
    echo             display: block;
    echo             text-decoration: none;
    echo             color: inherit;
    echo         }
    echo     ^</style^>
    echo ^</head^>
    echo ^<body^>
    echo     ^<div class="header"^>
    echo         ^<h1^>Primitive Technology Archive^</h1^>
    echo         ^<div class="stats"^>
    echo             Total Videos: !video_count! ^| Last Updated: !current_date!
    echo         ^</div^>
    echo     ^</div^>
    echo     ^<div class="video-grid"^>
) > "%STORAGE_DIR%\index.html"

:: Add video entries with progress counter
set "current=0"
for %%F in ("%VIDEOS_DIR%\*.mp4") do (
    set /a "current+=1"
    echo Processing video !current! of !video_count!: %%~nxF
    
    (
        echo     ^<div class="video-card"^>
        echo         ^<a href="Videos/%%~nxF" class="video-link"^>
        echo             ^<img class="thumbnail" src="Videos/%%~nF.jpg" alt="%%~nF"^>
        echo             ^<div class="video-info"^>
        echo                 ^<div class="video-title"^>%%~nF^</div^>
    ) >> "%STORAGE_DIR%\index.html"
    
    :: Add description if exists
    if exist "%%~dpnF.description" (
        echo             ^<div class="video-desc"^> >> "%STORAGE_DIR%\index.html"
        for /f "usebackq delims=" %%D in ("%%~dpnF.description") do (
            echo                 %%D >> "%STORAGE_DIR%\index.html"
        )
        echo             ^</div^> >> "%STORAGE_DIR%\index.html"
    )
    
    (
        echo             ^</div^>
        echo         ^</a^>
        echo     ^</div^>
    ) >> "%STORAGE_DIR%\index.html"
)

:: Close HTML
(
    echo     ^</div^>
    echo ^</body^>
    echo ^</html^>
) >> "%STORAGE_DIR%\index.html"

echo %GREEN%Index created successfully with !video_count! videos%NC%
exit /b

:verify_index
echo %YELLOW%Verifying index...%NC%
set "missing=0"
for %%F in ("%VIDEOS_DIR%\*.mp4") do (
    findstr /C:"%%~nxF" "%STORAGE_DIR%\index.html" >nul
    if errorlevel 1 (
        set /a "missing+=1"
        echo %RED%Missing from index: %%~nxF%NC%
    )
)
if !missing! gtr 0 (
    echo %YELLOW%Rebuilding index...%NC%
    call :create_index
) else (
    echo %GREEN%Index is complete%NC%
)
exit /b

endlocal 