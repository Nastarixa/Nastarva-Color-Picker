param(
    [string]$JsonPath,
    [string]$OutPath
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$data = Get-Content $JsonPath -Raw | ConvertFrom-Json

$showInfo = if ($data.showInfo -eq 1) { $true } else { $false }
$rowExtraH = if ($showInfo) { 22 } else { 0 }
$cellSize = 60
$cellGap = 4
$headerH = 30
$cols = $data.maxCols
$padding = 20
$sectionHeaderH = 24

$colors = $data.colors
$groups = @{}

foreach ($color in $colors) {
    $sec = if ($color.section) { $color.section } else { "Default" }
    if (-not $groups.ContainsKey($sec)) {
        $groups[$sec] = @()
    }
    $groups[$sec] += $color
}

$totalSections = $groups.Count
$rowsPerSection = @{}
$totalRows = 0
foreach ($sec in $groups.Keys) {
    $rows = [Math]::Ceiling($groups[$sec].Count / $cols)
    if ($rows -eq 0) { $rows = 1 }
    $rowsPerSection[$sec] = $rows
    $totalRows += $rows
}

$rowHeight = $cellSize + $rowExtraH
$totalHeight = $headerH + ($totalRows * ($rowHeight + $cellGap)) + ($totalSections * ($sectionHeaderH + $cellGap)) + $padding * 2
$totalWidth = ($cellSize + $cellGap) * $cols + $cellGap + $padding * 2

$bitmap = New-Object System.Drawing.Bitmap($totalWidth, $totalHeight)
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::White)

$font = New-Object System.Drawing.Font("Consolas", 8)
$fontBold = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$brushDark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 45, 45))
$brushGold = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 140, 90))
$brushGray = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 100, 100))
$brushHeader = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 45, 45))

$g.FillRectangle($brushHeader, 0, 0, $totalWidth, $headerH)
$g.DrawString($data.name, $fontBold, [System.Drawing.Brushes]::White, $padding, 6)

$y = $headerH + $padding + $cellGap

foreach ($sec in $groups.Keys) {
    $g.DrawString($sec, $fontBold, $brushDark, $padding, $y)
    $y += $sectionHeaderH

    $secColors = $groups[$sec]
    $x = $padding + $cellGap
    $count = 0

    foreach ($color in $secColors) {
        if ($count -gt 0 -and $count % $cols -eq 0) {
            $x = $padding + $cellGap
            $y += $rowHeight + $cellGap
        }

        $r = [Convert]::ToInt32($color.hex.Substring(0,2), 16)
        $gr = [Convert]::ToInt32($color.hex.Substring(2,2), 16)
        $b = [Convert]::ToInt32($color.hex.Substring(4,2), 16)
        $c = [System.Drawing.Color]::FromArgb(255, $r, $gr, $b)

        $rect = New-Object System.Drawing.Rectangle($x, $y, $cellSize, $cellSize)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush($c)), $rect)
        $g.DrawRectangle([System.Drawing.Pens]::DarkGray, $rect)

        if ($showInfo) {
            $infoY = $y + $cellSize + 2
            $hexText = "#" + $color.hex
            $g.DrawString($hexText, $font, $brushDark, $x, $infoY)
            $infoY += 9
            $rgbText = "$r,$gr,$b"
            $g.DrawString($rgbText, $font, $brushGray, $x, $infoY)
            $infoY += 9
            $roleText = if ($color.role) { $color.role } else { "Other" }
            $g.DrawString($roleText, $font, $brushGold, $x, $infoY)
        }

        $x += $cellSize + $cellGap
        $count++
    }

    $y += $rowHeight + $cellGap + $cellGap
}

$bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bitmap.Dispose()