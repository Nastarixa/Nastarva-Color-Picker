param(
    [string]$JsonPath,
    [string]$OutPath
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$data = Get-Content $JsonPath -Raw | ConvertFrom-Json

$cellSize = 60
$cellGap = 4
$headerH = 30
$cols = $data.maxCols
$padding = 20

$colors = $data.colors
$totalWidth = ($cellSize + $cellGap) * $cols + $cellGap + $padding * 2
$rows = [Math]::Ceiling($colors.Count / $cols)
$totalHeight = $headerH + ($cellSize + $cellGap) * $rows + $cellGap + $padding * 2

$bitmap = New-Object System.Drawing.Bitmap($totalWidth, $totalHeight)
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::FromArgb(50, 51, 56))

$font = New-Object System.Drawing.Font("Consolas", 9)
$brushWhite = [System.Drawing.Brushes]::White

$g.FillRectangle([System.Drawing.Brushes]::DimGray, 0, 0, $totalWidth, $headerH)
$g.DrawString($data.name, $font, $brushWhite, $padding, 6)

$x = $padding + $cellGap
$y = $headerH + $padding + $cellGap
$count = 0

foreach ($color in $colors) {
    if ($count -gt 0 -and $count % $cols -eq 0) {
        $x = $padding + $cellGap
        $y += $cellSize + $cellGap
    }

    $r = [Convert]::ToInt32($color.hex.Substring(0,2), 16)
    $gr = [Convert]::ToInt32($color.hex.Substring(2,2), 16)
    $b = [Convert]::ToInt32($color.hex.Substring(4,2), 16)
    $c = [System.Drawing.Color]::FromArgb(255, $r, $gr, $b)

    $rect = New-Object System.Drawing.Rectangle($x, $y, $cellSize, $cellSize)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($c)), $rect)
    $g.DrawRectangle([System.Drawing.Pens]::DarkGray, $rect)

    $dark = [System.Drawing.Color]::FromArgb(180, [Math]::Max($r - 50, 0), [Math]::Max($gr - 50, 0), [Math]::Max($b - 50, 0))
    $light = [System.Drawing.Color]::FromArgb(180, [Math]::Min($r + 50, 255), [Math]::Min($gr + 50, 255), [Math]::Min($b + 50, 255))

    $g.FillRectangle((New-Object System.Drawing.SolidBrush($dark)), $x, $y, $cellSize, 2)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($light)), $x, $y + $cellSize - 2, $cellSize, 2)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($dark)), $x, $y, 2, $cellSize)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush($light)), $x + $cellSize - 2, $y, 2, $cellSize)

    $hexText = "#" + $color.hex
    $textWidth = $g.MeasureString($hexText, $font).Width
    $gx = $x + ($cellSize - $textWidth) / 2
    $gy = $y + ($cellSize - 9) / 2
    $g.DrawString($hexText, $font, $brushWhite, $gx, $gy)

    $x += $cellSize + $cellGap
    $count++
}

$bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bitmap.Dispose()