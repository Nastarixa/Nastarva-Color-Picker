param(
    [string]$JsonPath,
    [string]$OutPath
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$data = Get-Content $JsonPath -Raw | ConvertFrom-Json

$debugFile = $env:TEMP + "\nastarxa_debug.txt"
$debugInfo = "Colors: " + ($data.colors | ConvertTo-Json -Compress) + "`nmaxCols: " + $data.maxCols + "`nSections: " + ($data.sections | ConvertTo-Json -Compress)
Set-Content -Path $debugFile -Value $debugInfo

$colors = @($data.colors)
$groups = @{}

foreach ($color in $colors) {
    $sec = if ($color.section) { $color.section } else { "Default" }
    if (-not $groups.ContainsKey($sec)) {
        $groups[$sec] = @()
    }
    $groups[$sec] += $color
}

$orderedSections = @()
foreach ($secName in $data.sections) {
    if ($groups.ContainsKey($secName)) {
        $orderedSections += $secName
    }
}
foreach ($sec in $groups.Keys) {
    if ($orderedSections -notcontains $sec) {
        $orderedSections += $sec
    }
}

$rowsPerSection = @{}
$totalHeight = $headerH + $padding
foreach ($sec in $orderedSections) {
    $rows = [Math]::Ceiling($groups[$sec].Count / $cols)
    if ($rows -eq 0) { $rows = 1 }
    $rowsPerSection[$sec] = $rows
    $totalHeight += $sectionHeaderH + ($rows * $rowHeight) + ([Math]::Max(0, $rows - 1) * $cellGap) + $sectionGap
}
$totalHeight += $padding
$totalWidth = ($cellW * $cols) + ([Math]::Max(0, $cols - 1) * $cellGap) + ($padding * 2)

$bitmap = New-Object System.Drawing.Bitmap($totalWidth, $totalHeight)
$bitmap.SetResolution(120, 120)
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::White)

$font = New-Object System.Drawing.Font("Consolas", 8)
$fontSmall = New-Object System.Drawing.Font("Consolas", 7)
$fontBold = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$fontTitle = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$brushDark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(25, 25, 25))
$brushGray = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 90, 90))
$brushWhite = [System.Drawing.Brushes]::White
$penBlue = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0, 0, 255), 1.5)
$penSection = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(195, 195, 195), 1)

$g.DrawString($data.name, $fontTitle, $brushDark, $padding, 10)

$y = $headerH + $padding

foreach ($sec in $orderedSections) {
    $g.DrawString($sec, $fontBold, $brushDark, $padding, $y)
    $lineY = $y + 22
    $g.DrawLine($penSection, $padding, $lineY, $totalWidth - $padding, $lineY)
    $y += $sectionHeaderH

    $secColors = $groups[$sec]
    $x = $padding
    $count = 0

    foreach ($color in $secColors) {
        if ($count -gt 0 -and $count % $cols -eq 0) {
            $x = $padding
            $y += $rowHeight + $cellGap
        }

        $r = [Convert]::ToInt32($color.hex.Substring(0, 2), 16)
        $gr = [Convert]::ToInt32($color.hex.Substring(2, 2), 16)
        $b = [Convert]::ToInt32($color.hex.Substring(4, 2), 16)
        $c = [System.Drawing.Color]::FromArgb(255, $r, $gr, $b)
        $brightness = (($r * 299) + ($gr * 587) + ($b * 114)) / 1000
        $textBrush = if ($brightness -lt 150) { $brushWhite } else { $brushDark }

        $rect = New-Object System.Drawing.Rectangle($x, $y, $cellW, $cellH)
        $swatchBrush = New-Object System.Drawing.SolidBrush($c)
        $g.FillRectangle($swatchBrush, $rect)
        $g.DrawRectangle($penBlue, $rect)
        $swatchBrush.Dispose()

        $roleText = if ($color.role) { $color.role } else { "Base" }
        $roleSize = $g.MeasureString($roleText, $font)
        $roleX = $x + (($cellW - $roleSize.Width) / 2)
        $roleY = $y + $cellH - 18
        $g.DrawString($roleText, $font, $textBrush, $roleX, $roleY)

        $infoY = $y + $cellH + 3
        $hexText = "#" + $color.hex
        $hexSize = $g.MeasureString($hexText, $fontBold)
        $hexX = $x + (($cellW - $hexSize.Width) / 2)
        $g.DrawString($hexText, $fontBold, $brushDark, $hexX, $infoY)

        if ($showInfo) {
            $rgbText = "$r,$gr,$b"
            $rgbSize = $g.MeasureString($rgbText, $fontSmall)
            $rgbX = $x + (($cellW - $rgbSize.Width) / 2)
            $g.DrawString($rgbText, $fontSmall, $brushGray, $rgbX, $infoY + 14)
        }

        $x += $cellW + $cellGap
        $count++
    }

    if ($secColors.Count -eq 0) {
        $g.DrawString("No colors in this section", $font, $brushGray, $padding, $y + 4)
        $y += 24
    } else {
        $rowsUsed = $rowsPerSection[$sec]
        $y += ($rowsUsed * $rowHeight) + ([Math]::Max(0, $rowsUsed - 1) * $cellGap)
    }

    $y += $sectionGap
}

$bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$penBlue.Dispose()
$penSection.Dispose()
$brushDark.Dispose()
$brushGray.Dispose()
$font.Dispose()
$fontSmall.Dispose()
$fontBold.Dispose()
$fontTitle.Dispose()
$g.Dispose()
$bitmap.Dispose()
