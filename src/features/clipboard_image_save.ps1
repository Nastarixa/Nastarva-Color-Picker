param(
    [string]$OutPath
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try {
    $image = Get-Clipboard -Format Image
} catch {
    $image = $null
}

if (-not $image) {
    exit 1
}

$dir = Split-Path -Parent $OutPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
}

if (Test-Path $OutPath) {
    Remove-Item -LiteralPath $OutPath -Force
}

$image.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
exit 0
