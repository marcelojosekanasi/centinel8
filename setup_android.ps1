$ErrorActionPreference = "Continue"

$sdkRoot = "C:\Users\isana\AppData\Local\Android\sdk"
$cmdlineDir = Join-Path $sdkRoot "cmdline-tools"
$zipPath = Join-Path $sdkRoot "cmdline-tools-download.zip"

# Step 1: Download cmdline-tools
Write-Host "=== STEP 1: Downloading Android cmdline-tools ===" -ForegroundColor Green
Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" -OutFile $zipPath
Write-Host "Download complete: $zipPath"

# Step 2: Extract
Write-Host "=== STEP 2: Extracting ===" -ForegroundColor Green
$tempExtract = Join-Path $sdkRoot "cmdline-tools-temp"
Remove-Item -Recurse -Force $tempExtract -ErrorAction SilentlyContinue
Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force

# Step 3: Move to correct location (cmdline-tools/latest)
Write-Host "=== STEP 3: Setting up folder structure ===" -ForegroundColor Green
$latestDir = Join-Path $cmdlineDir "latest"
Remove-Item -Recurse -Force $latestDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $latestDir | Out-Null

# The zip extracts to a folder called "cmdline-tools" inside tempExtract
$extractedInner = Join-Path $tempExtract "cmdline-tools"
if (Test-Path $extractedInner) {
    Copy-Item -Recurse -Force -Path "$extractedInner\*" -Destination $latestDir
} else {
    Copy-Item -Recurse -Force -Path "$tempExtract\*" -Destination $latestDir
}
Write-Host "cmdline-tools installed at: $latestDir"

# Step 4: Accept licenses
Write-Host "=== STEP 4: Accepting Android licenses ===" -ForegroundColor Green
$sdkmanager = Join-Path $latestDir "bin\sdkmanager.bat"
if (Test-Path $sdkmanager) {
    echo "y`ny`ny`ny`ny`ny`ny`ny`ny`ny" | & $sdkmanager --licenses --sdk_root=$sdkRoot
} else {
    Write-Host "sdkmanager not found at $sdkmanager, trying flutter..."
    echo "y`ny`ny`ny`ny`ny`ny`ny`ny`ny" | flutter doctor --android-licenses
}

# Step 5: Flutter doctor
Write-Host "=== STEP 5: Flutter doctor ===" -ForegroundColor Green
flutter doctor -v

# Step 6: List emulators
Write-Host "=== STEP 6: Listing emulators ===" -ForegroundColor Green
flutter emulators

Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
