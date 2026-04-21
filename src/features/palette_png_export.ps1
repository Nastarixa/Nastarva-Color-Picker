param(
    [string]$JsonPath,
    [string]$OutPath
)

Add-Type -AssemblyName System.Drawing

$data = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
$count = [Math]::Max(1, $data.colors.Count)
$cols = [Math]::Min([Math]::Max(1, [int]$data.maxCols), 8)
$cols = [Math]::Min($cols, $count)
$rows = [Math]::Ceiling($count / $cols)

$padding = 24
$gap = 18
$swatchW = 84
$swatchH = 84
$labelH = 22
$titleH = 46

$width = ($padding * 2) + ($cols * $swatchW) + (($cols - 1) * $gap)
$height = ($padding * 2) + $titleH + ($rows * ($swatchH + $labelH)) + (($rows - 1) * $gap)

$bmp = New-Object System.Drawing.Bitmap($width, $height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$g.Clear([System.Drawing.Color]::FromArgb(247,245,240))

$titleFont = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$hexFont = New-Object System.Drawing.Font("Consolas", 10)
$roleFont = New-Object System.Drawing.Font("Segoe UI", 9)
$textBrush = [System.Drawing.Brushes]::Black
$whiteBrush = [System.Drawing.Brushes]::White
$borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(42,42,42), 1)

$g.DrawString($data.name, $titleFont, $textBrush, $padding, $padding - 2)

if ($data.colors.Count -eq 0) {
    $g.DrawString("No colors in this palette", $roleFont, $textBrush, $padding, $padding + $titleH)
} else {
    for ($i = 0; $i -lt $data.colors.Count; $i++) {
        $item = $data.colors[$i]
        $col = $i % $cols
        $row = [Math]::Floor($i / $cols)
        $x = $padding + $col * ($swatchW + $gap)
        $y = $padding + $titleH + $row * ($swatchH + $labelH + $gap)

        $color = [System.Drawing.ColorTranslator]::FromHtml("#" + $item.hex)
        $brush = New-Object System.Drawing.SolidBrush($color)
        $g.FillRectangle($brush, $x, $y, $swatchW, $swatchH)
        $g.DrawRectangle($borderPen, $x, $y, $swatchW, $swatchH)

        $brightness = (($color.R * 299) + ($color.G * 587) + ($color.B * 114)) / 1000
        $roleBrush = if ($brightness -lt 145) { $whiteBrush } else { $textBrush }

        $hexRect = New-Object System.Drawing.RectangleF($x, ($y + $swatchH + 4), $swatchW, $labelH)
        $roleRect = New-Object System.Drawing.RectangleF(($x + 4), ($y + $swatchH - 20), ($swatchW - 8), 16)
        $fmtCenter = New-Object System.Drawing.StringFormat
        $fmtCenter.Alignment = [System.Drawing.StringAlignment]::Center

        $g.DrawString("#" + $item.hex, $hexFont, $textBrush, $hexRect, $fmtCenter)
        $g.DrawString([string]$item.role, $roleFont, $roleBrush, $roleRect, $fmtCenter)

        $fmtCenter.Dispose()
        $brush.Dispose()
    }
}

$dir = Split-Path -Parent $OutPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
}

$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)

$borderPen.Dispose()
$titleFont.Dispose()
$hexFont.Dispose()
$roleFont.Dispose()
$g.Dispose()
$bmp.Dispose()
