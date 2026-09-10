# Prompt the user for the target file name to split
$inputFile = Read-Host -Prompt "Enter the target file name to split (e.g., GrannyPortButBetter.data.unityweb)"

# Clean up quotes from drag-and-drop or copy-pasting
$inputFile = $inputFile.Trim('"').Trim("'")

if ([string]::IsNullOrWhiteSpace($inputFile)) {
    Write-Host "No file name entered. Exiting script." -ForegroundColor Red
    exit
}

$sourcePath = Join-Path -Path $PSScriptRoot -ChildPath $inputFile

if (-not (Test-Path $sourcePath)) {
    Write-Host "Error: Could not find file '$inputFile' in script directory." -ForegroundColor Red
    exit
}

# Set chunk size to 20 MB (20 * 1024 * 1024 bytes)
$chunkSizeBytes = 20 * 1024 * 1024 
$bufferSize = 64 * 1024 # Read in 64 KB chunks
$buffer = New-Object byte[] $bufferSize

$partIndex = 1
$totalBytesRead = 0
$fileSize = (Get-Item $sourcePath).Length

Write-Host "`nStarting split for $inputFile ($fileSize bytes)..." -ForegroundColor Cyan

# Open the original large file for reading
$inputStream = [System.IO.File]::OpenRead($sourcePath)

try {
    while ($totalBytesRead -lt $fileSize) {
        $partName = "$inputFile.part$partIndex"
        $partPath = Join-Path -Path $PSScriptRoot -ChildPath $partName
        
        # Remove existing part file if present
        if (Test-Path $partPath) { Remove-Item $partPath }

        $outputStream = [System.IO.File]::Create($partPath)
        $bytesWrittenToPart = 0

        try {
            while ($bytesWrittenToPart -lt $chunkSizeBytes -and $totalBytesRead -lt $fileSize) {
                # Calculate remaining bytes to read for this 20 MB part
                $bytesToRead = [Math]::Min($bufferSize, ($chunkSizeBytes - $bytesWrittenToPart))
                $bytesToRead = [Math]::Min($bytesToRead, ($fileSize - $totalBytesRead))

                $bytesRead = $inputStream.Read($buffer, 0, $bytesToRead)
                if ($bytesRead -eq 0) { break }

                $outputStream.Write($buffer, 0, $bytesRead)
                $bytesWrittenToPart += $bytesRead
                $totalBytesRead += $bytesRead
            }
        } finally {
            $outputStream.Close()
        }

        Write-Host "Created: $partName ($bytesWrittenToPart bytes)" -ForegroundColor Green
        $partIndex++
    }
} finally {
    $inputStream.Close()
}

Write-Host "`nSuccessfully split $inputFile into $(($partIndex - 1)) parts." -ForegroundColor Yellow

# --- AUTOMATED RENAME STEP ---
Write-Host "`nRenaming non-split assets to standardize template names..." -ForegroundColor Cyan

# Extract prefix (e.g., "GrannyPortButBetter" from "GrannyPortButBetter.data.unityweb")
$prefix = $inputFile -split '\.' | Select-Object -First 1

# 1. Rename framework file
$frameworkFile = Get-Item "$prefix*.framework.unityweb" -ErrorAction SilentlyContinue
if ($frameworkFile) {
    Rename-Item -Path $frameworkFile.FullName -NewName "build.framework.js" -Force
    Write-Host "Renamed $($frameworkFile.Name) -> build.framework.js" -ForegroundColor Green
}

# 2. Rename code/wasm file
$wasmFile = Get-Item "$prefix*.code.unityweb" -ErrorAction SilentlyContinue
if ($wasmFile) {
    Rename-Item -Path $wasmFile.FullName -NewName "build.wasm" -Force
    Write-Host "Renamed $($wasmFile.Name) -> build.wasm" -ForegroundColor Green
}

# 3. Rename UnityLoader.js
if (Test-Path "UnityLoader.js") {
    Rename-Item -Path "UnityLoader.js" -NewName "unity.loader.js" -Force
    Write-Host "Renamed UnityLoader.js -> unity.loader.js" -ForegroundColor Green
}

Write-Host "`nAll operations complete! Part files generated and assets renamed." -ForegroundColor Yellow