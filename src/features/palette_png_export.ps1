param(
    [string]$JsonPath,
    [string]$OutPath
)

Add-Type -AssemblyName System.Drawing

$data = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
$colors = @($data.colors)
$sectionNames = @()
if ($data.PSObject.Properties.Name -contains 'sections') {
    $sectionNames = @($data.sections)
}

if ($sectionNames.Count -eq 0) {
    $sectionNames = @("Default")
}

$groups = @()
foreach ($sectionName in $sectionNames) {
    $name = if ([string]::IsNullOrWhiteSpace([string]$sectionName)) { "Default" } else { [string]$sectionName }
    $items = @($colors | Where-Object {
        $itemSection = if ($_.PSObject.Properties.Name -contains 'section') { [string]$_.section } else { "Default" }
        if ([string]::IsNullOrWhiteSpace($itemSection)) { $itemSection = "Default" }
        $itemSection -eq $name
    })
    $groups += [PSCustomObject]@{
        Name = $name
        Items = $items
    }
}

$extraSections = @($colors | ForEach-Object {
    if ($_.PSObject.Properties.Name -contains 'section') {
        $itemSection = [string]$_.section
        if ([string]::IsNullOrWhiteSpace($itemSection)) { $itemSection = "Default" }
        $itemSection
    } else {
        "Default"
    }
} | Select-Object -Unique | Where-Object { $_ -notin $sectionNames })

foreach ($sectionName in $extraSections) {
    $items = @($colors | Where-Object {
        $itemSection = if ($_.PSObject.Properties.Name -contains 'section') { [string]$_.section } else { "Default" }
        if ([string]::IsNullOrWhiteSpace($itemSection)) { $itemSection = "Default" }
        $itemSection -eq $sectionName
    })
    $groups += [PSCustomObject]@{
        Name = $sectionName
        Items = $items
    }
}

$maxCols = [Math]::Min([Math]::Max(1, [int]$data.maxCols), 8)
$padding = 24
$gap = 18
$swatchW = 108
$swatchH = 76
$hexH = 18
$rgbH = 18
$roleH = 18
$cellH = $swatchH + $hexH + $rgbH + $roleH + 10
$titleH = 48
$sectionHeaderH = 28
$sectionGap = 26

$maxColsUsed = 1
$totalContentH = 0
foreach ($group in $groups) {
    $count = [Math]::Max(1, $group.Items.Count)
    $cols = [Math]::Min($maxCols, $count)
    $rows = [Math]::Ceiling($count / $cols)
    $maxColsUsed = [Math]::Max($maxColsUsed, $cols)
    $totalContentH += $sectionHeaderH + ($rows * $cellH) + (($rows - 1) * $gap) + $sectionGap
}

$width = ($padding * 2) + ($maxColsUsed * $swatchW) + (($maxColsUsed - 1) * $gap)
$height = ($padding * 2) + $titleH + [Math]::Max($sectionHeaderH + $cellH, $totalContentH)

$bmp = New-Object System.Drawing.Bitmap($width, $height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$g.Clear([System.Drawing.Color]::FromArgb(247,245,240))

$titleFont = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$sectionFont = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$hexFont = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$rgbFont = New-Object System.Drawing.Font("Consolas", 9)
$roleFont = New-Object System.Drawing.Font("Segoe UI", 9)
$textBrush = [System.Drawing.Brushes]::Black
$mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(85, 85, 85))
$headerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(42, 42, 42))
$headerTextBrush = [System.Drawing.Brushes]::White
$whiteBrush = [System.Drawing.Brushes]::White
$borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(42,42,42), 1)
$sectionLinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(185,185,185), 1)
$fmtCenter = New-Object System.Drawing.StringFormat
$fmtCenter.Alignment = [System.Drawing.StringAlignment]::Center

$g.DrawString([string]$data.name, $titleFont, $textBrush, $padding, $padding - 2)

$yCursor = $padding + $titleH
foreach ($group in $groups) {
    $items = @($group.Items)
    $count = [Math]::Max(1, $items.Count)
    $cols = [Math]::Min($maxCols, $count)
    $rows = [Math]::Ceiling($count / $cols)

    $headerRect = New-Object System.Drawing.RectangleF($padding, $yCursor, ($width - ($padding * 2)), $sectionHeaderH)
    $g.FillRectangle($headerBrush, $headerRect.X, $headerRect.Y, $headerRect.Width, $headerRect.Height)
    $g.DrawString([string]$group.Name, $sectionFont, $headerTextBrush, ($padding + 10), ($yCursor + 3))
    $yCursor += $sectionHeaderH + 8

    if ($items.Count -eq 0) {
        $g.DrawString("No colors in this section", $rgbFont, $mutedBrush, $padding, $yCursor + 4)
        $yCursor += $cellH
    } else {
        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            $col = $i % $cols
            $row = [Math]::Floor($i / $cols)
            $x = $padding + $col * ($swatchW + $gap)
            $y = $yCursor + $row * ($cellH + $gap)

            $color = [System.Drawing.ColorTranslator]::FromHtml("#" + $item.hex)
            $brush = New-Object System.Drawing.SolidBrush($color)
            $g.FillRectangle($brush, $x, $y, $swatchW, $swatchH)
            $g.DrawRectangle($borderPen, $x, $y, $swatchW, $swatchH)

            $brightness = (($color.R * 299) + ($color.G * 587) + ($color.B * 114)) / 1000
            $roleBrush = if ($brightness -lt 145) { $whiteBrush } else { $textBrush }

            $roleRect = New-Object System.Drawing.RectangleF(($x + 4), ($y + $swatchH - 20), ($swatchW - 8), 16)
            $hexRect = New-Object System.Drawing.RectangleF($x, ($y + $swatchH + 2), $swatchW, $hexH)
            $rgbRect = New-Object System.Drawing.RectangleF($x, ($y + $swatchH + 20), $swatchW, $rgbH)

            $g.DrawString([string]$item.role, $roleFont, $roleBrush, $roleRect, $fmtCenter)
            $g.DrawString("#" + [string]$item.hex, $hexFont, $textBrush, $hexRect, $fmtCenter)
            $g.DrawString([string]$item.rgb, $rgbFont, $mutedBrush, $rgbRect, $fmtCenter)

            $brush.Dispose()
        }

        $yCursor += ($rows * $cellH) + (($rows - 1) * $gap)
    }

    $g.DrawLine($sectionLinePen, $padding, $yCursor + 6, ($width - $padding), $yCursor + 6)
    $yCursor += $sectionGap
}

$dir = Split-Path -Parent $OutPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
}

$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)

$fmtCenter.Dispose()
$sectionLinePen.Dispose()
$borderPen.Dispose()
$headerBrush.Dispose()
$mutedBrush.Dispose()
$titleFont.Dispose()
$sectionFont.Dispose()
$hexFont.Dispose()
$rgbFont.Dispose()
$roleFont.Dispose()
$g.Dispose()
$bmp.Dispose()
