# AI Chat Project Setup Script
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Admin check
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "⚠️ Please run as Administrator!" -ForegroundColor Red
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Simple error logging
function Write-Error-Log {
    param([string]$Message)
    Write-Host "❌ Error: $Message" -ForegroundColor Red
    Add-Content -Path "$env:TEMP\oma_install.log" -Value "$(Get-Date) - ERROR: $Message"
}

# Simple version check
function Test-CommandVersion {
    param(
        [string]$Command,
        [string]$MinVersion
    )
    
    try {
        $version = (Invoke-Expression "$Command --version") 2>&1
        if ($version -match '(\d+\.\d+\.\d+)') {
            return [version]$matches[1] -ge [version]$MinVersion
        }
    }
    catch {
        return $false
    }
    return $false
}

# Simple download function
function Get-FileWithRetry {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$Retries = 3
    )
    
    $i = 1
    while ($i -le $Retries) {
        try {
            Write-Host "📥 Download attempt $i of $Retries..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
            return $true
        } catch {
            if ($i -eq $Retries) {
                Write-Error-Log "Download failed: $Url"
                return $false
            }
            Start-Sleep -Seconds 5
            $i++
        }
    }
    return $false
}

# Setup variables
$InstallPath = "C:\AI_Tools"
$LogPath = "$env:TEMP\oma_install.log"

# Create directories
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null

# Install Python if needed
if (-not (Test-CommandVersion "python" "3.12.0")) {
    Write-Host "🐍 Installing Python..." -ForegroundColor Cyan
    $pythonUrl = "https://www.python.org/ftp/python/3.12.2/python-3.12.2-amd64.exe"
    if (Get-FileWithRetry -Url $pythonUrl -OutFile "$InstallPath\python_installer.exe") {
        Start-Process -Wait -FilePath "$InstallPath\python_installer.exe" -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1"
        Remove-Item "$InstallPath\python_installer.exe" -Force
    }
}

# Install Git if needed
if (-not (Test-CommandVersion "git" "2.40.0")) {
    Write-Host "🔧 Installing Git..." -ForegroundColor Cyan
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/Git-2.44.0-64-bit.exe"
    if (Get-FileWithRetry -Url $gitUrl -OutFile "$InstallPath\git_installer.exe") {
        Start-Process -Wait -FilePath "$InstallPath\git_installer.exe" -ArgumentList "/VERYSILENT /NORESTART"
        Remove-Item "$InstallPath\git_installer.exe" -Force
    }
}

# Install CMake if needed
if (-not (Test-CommandVersion "cmake" "3.28.0")) {
    Write-Host "🔧 Installing CMake..." -ForegroundColor Cyan
    $cmakeUrl = "https://github.com/Kitware/CMake/releases/download/v3.28.3/cmake-3.28.3-windows-x86_64.msi"
    if (Get-FileWithRetry -Url $cmakeUrl -OutFile "$InstallPath\cmake_installer.msi") {
        Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/i `"$InstallPath\cmake_installer.msi`" /quiet"
        Remove-Item "$InstallPath\cmake_installer.msi" -Force
    }
}

# Install FFmpeg if needed
if (-not (Test-Path "C:\ffmpeg\bin\ffmpeg.exe")) {
    Write-Host "🎥 Installing FFmpeg..." -ForegroundColor Cyan
    $ffmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    if (Get-FileWithRetry -Url $ffmpegUrl -OutFile "$InstallPath\ffmpeg.zip") {
        Expand-Archive -Path "$InstallPath\ffmpeg.zip" -DestinationPath "C:\ffmpeg" -Force
        Get-ChildItem -Path "C:\ffmpeg" -Filter "ffmpeg-*" | ForEach-Object { 
            Move-Item "$($_.FullName)\*" "C:\ffmpeg" -Force 
        }
        Remove-Item "$InstallPath\ffmpeg.zip" -Force
        $env:Path += ";C:\ffmpeg\bin"
        [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
    }
}

# Clone and build llama.cpp
$RepoPath = Join-Path $InstallPath "llama.cpp"
if (-not (Test-Path $RepoPath)) {
    Write-Host "🔄 Setting up AI model..." -ForegroundColor Cyan
    git clone --depth 1 https://github.com/ggerganov/llama.cpp.git $RepoPath
    Push-Location $RepoPath
    mkdir build -ErrorAction SilentlyContinue
    Set-Location build
    cmake ..
    cmake --build . --config Release
    Pop-Location
}

# Download AI model
$ModelPath = Join-Path $RepoPath "models\TinyLlama-1B.Q4_K_M.gguf"
if (-not (Test-Path $ModelPath)) {
    Write-Host "📥 Downloading AI model..." -ForegroundColor Cyan
    $ModelUrl = "https://huggingface.co/TheBloke/TinyLlama-1B-GGUF/resolve/main/TinyLlama-1B.Q4_K_M.gguf"
    Get-FileWithRetry -Url $ModelUrl -OutFile $ModelPath
}

Write-Host "✅ Installation complete!" -ForegroundColor Green
Write-Host "📁 Installation path: $InstallPath" -ForegroundColor Cyan
Write-Host "📝 Log file: $LogPath" -ForegroundColor Cyan

# Test the download function
Write-Host "🔄 Testing download function..." -ForegroundColor Cyan
$TestUrl = "https://www.python.org/ftp/python/3.12.2/python-3.12.2-amd64.exe"
if (Get-FileWithRetry -Url $TestUrl -OutFile "$InstallPath\test.exe") {
    Write-Host "✅ Download test successful" -ForegroundColor Green
    Remove-Item "$InstallPath\test.exe" -Force
} else {
    Write-Host "❌ Download test failed" -ForegroundColor Red
} 