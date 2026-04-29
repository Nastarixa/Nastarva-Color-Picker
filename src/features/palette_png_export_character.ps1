param(
    [string]$JsonPath,
    [string]$OutPath
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$data = Get-Content $JsonPath -Raw | ConvertFrom-Json

function Get-SectionNames {
    param($Data, $Groups)

    $names = @()
    foreach ($section in $Data.sections) {
        if ($Groups.ContainsKey($section)) {
            $names += $section
        }
    }
    foreach ($name in $Groups.Keys) {
        if ($names -notcontains $name) {
            $names += $name
        }
    }
    return $names
}

function Get-ColorObject {
    param([string]$Hex)
    if ([string]::IsNullOrWhiteSpace($Hex) -or $Hex.Length -lt 6) {
        return [System.Drawing.Color]::FromArgb(255, 128, 128, 128)
    }
    $r = [Convert]::ToInt32($Hex.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($Hex.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($Hex.Substring(4, 2), 16)
    return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
}

function Normalize-ExportRole {
    param([string]$Role)

    if ([string]::IsNullOrWhiteSpace($Role)) {
        return "Base"
    }

    $clean = $Role.Trim()
    if ($clean -eq "BL") {
        return "Black"
    }

    return $clean
}

function Get-TextBrush {
    param([System.Drawing.Color]$Color)
    $luma = (($Color.R * 299) + ($Color.G * 587) + ($Color.B * 114)) / 1000
    if ($luma -lt 150) {
        return [System.Drawing.Brushes]::White
    }
    return [System.Drawing.Brushes]::Black
}

function Draw-CenteredText {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Text,
        [System.Drawing.Font]$Font,
        [System.Drawing.Brush]$Brush,
        [System.Drawing.RectangleF]$Rect
    )

    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
    $Graphics.DrawString($Text, $Font, $Brush, $Rect, $fmt)
    $fmt.Dispose()
}

function Draw-MainSwatch {
    param(
        [System.Drawing.Graphics]$Graphics,
        $ColorItem,
        [float]$X,
        [float]$Y,
        [float]$W,
        [float]$H,
        [System.Drawing.Pen]$PenBlue,
        [System.Drawing.Font]$HexFont,
        [System.Drawing.Font]$RgbFont
    )

    $colorObj = Get-ColorObject $ColorItem.hex
    $brush = New-Object System.Drawing.SolidBrush($colorObj)
    $rect = New-Object System.Drawing.RectangleF($X, $Y, $W, $H)
    $Graphics.FillRectangle($brush, $rect)
    $Graphics.DrawRectangle($PenBlue, $X, $Y, $W, $H)

    $textBrush = Get-TextBrush $colorObj
    $hexRect = New-Object System.Drawing.RectangleF($X, $Y + 8, $W, 18)
    $rgbRect = New-Object System.Drawing.RectangleF($X, $Y + 28, $W, 16)
    Draw-CenteredText $Graphics $ColorItem.hex $HexFont $textBrush $hexRect
    Draw-CenteredText $Graphics $ColorItem.rgb $RgbFont $textBrush $rgbRect
    $brush.Dispose()
}

function Draw-SideSwatch {
    param(
        [System.Drawing.Graphics]$Graphics,
        $ColorItem,
        [float]$X,
        [float]$Y,
        [float]$W,
        [float]$H,
        [float]$TextX,
        [System.Drawing.Pen]$PenBlue,
        [System.Drawing.Font]$HexFont,
        [System.Drawing.Font]$RgbFont
    )

    $colorObj = Get-ColorObject $ColorItem.hex
    $brush = New-Object System.Drawing.SolidBrush($colorObj)
    $Graphics.FillRectangle($brush, $X, $Y, $W, $H)
    $Graphics.DrawRectangle($PenBlue, $X, $Y, $W, $H)

    $Graphics.DrawString($ColorItem.hex, $HexFont, [System.Drawing.Brushes]::Black, $TextX, $Y + 2)
    $Graphics.DrawString($ColorItem.rgb, $RgbFont, [System.Drawing.Brushes]::Black, $TextX, $Y + 18)
    $brush.Dispose()
}

function Draw-Connector {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Pen]$PenBlue,
        [float]$X1,
        [float]$Y1,
        [float]$X2,
        [float]$Y2
    )
    $Graphics.DrawLine($PenBlue, $X1, $Y1, $X2, $Y2)
}

function Draw-RoleBoard {
    param(
        [System.Drawing.Graphics]$Graphics,
        $SectionColors,
        [float]$CardX,
        [float]$CardY,
        [System.Drawing.Pen]$PenBlue,
        [System.Drawing.Font]$HexFont,
        [System.Drawing.Font]$RgbFont,
        [System.Drawing.Font]$SectionFont,
        [System.Drawing.Pen]$PenDivider
    )

    $byRole = @{}
    foreach ($color in $SectionColors) {
        $role = if ($color.role) { [string]$color.role } else { "Base" }
        $byRole[$role] = $color
    }

    $base = if ($byRole.ContainsKey("Base")) { $byRole["Base"] } else { $null }
    $shadow = if ($byRole.ContainsKey("Shadow")) { $byRole["Shadow"] } else { $null }
    $shadow2 = if ($byRole.ContainsKey("2 Shadow")) { $byRole["2 Shadow"] } else { $null }
    $highlight = if ($byRole.ContainsKey("Highlight")) { $byRole["Highlight"] } else { $null }
    $hiShadow = if ($byRole.ContainsKey("Hi Shadow")) { $byRole["Hi Shadow"] } else { $null }

    $stackX = $CardX + 24
    $stackY = $CardY + 36
    $mainW = 98
    $mainH = 38
    $smallW = 42
    $smallH = 34
    $smallX = $stackX + $mainW - 2

    if ($base) {
        Draw-MainSwatch $Graphics $base $stackX $stackY $mainW $mainH $PenBlue $HexFont $RgbFont
    }
    if ($shadow) {
        Draw-MainSwatch $Graphics $shadow $stackX ($stackY + $mainH - 1) $mainW $mainH $PenBlue $HexFont $RgbFont
    }
    if ($shadow2) {
        Draw-MainSwatch $Graphics $shadow2 $stackX ($stackY + ($mainH * 2) - 2) $mainW $mainH $PenBlue $HexFont $RgbFont
    }

    if ($highlight) {
        $highlightY = $stackY - 10
        Draw-SideSwatch $Graphics $highlight $smallX $highlightY $smallW $smallH ($smallX + $smallW + 8) $PenBlue $HexFont $RgbFont
        Draw-Connector $Graphics $PenBlue ($stackX + $mainW) ($stackY + 4) $smallX ($highlightY + 18)
    }

    if ($hiShadow) {
        $hiShadowY = $stackY + $mainH - 2
        Draw-SideSwatch $Graphics $hiShadow $smallX $hiShadowY $smallW $smallH ($smallX + $smallW + 8) $PenBlue $HexFont $RgbFont
        Draw-Connector $Graphics $PenBlue ($stackX + $mainW) ($stackY + $mainH + 8) $smallX ($hiShadowY + 16)
    }

    $extraRoles = @("Outline", "Black", "Mask", "BL")
    $extraIndex = 0
    foreach ($extraRole in $extraRoles) {
        if (-not $byRole.ContainsKey($extraRole)) {
            continue
        }
        $extra = $byRole[$extraRole]
        $extraX = $CardX + 150
        $extraY = $CardY + 28 + ($extraIndex * 92)
        $Graphics.DrawString($extraRole, $HexFont, [System.Drawing.Brushes]::Black, $extraX, $extraY)
        Draw-MainSwatch $Graphics $extra ($extraX + 2) ($extraY + 20) 88 44 $PenBlue $HexFont $RgbFont
        $extraIndex++
    }
}

$groups = @{}
foreach ($color in $data.colors) {
    $sec = if ($color.section) { $color.section } else { "Default" }
    $color.role = Normalize-ExportRole $color.role
    if (-not $groups.ContainsKey($sec)) {
        $groups[$sec] = @()
    }
    $groups[$sec] += $color
}

$sectionNames = Get-SectionNames $data $groups
$cardCols = 4
$cardW = 260
$cardH = 250
$gapX = 26
$gapY = 44
$padding = 34
$headerH = 58

$rows = [Math]::Ceiling([Math]::Max(1, $sectionNames.Count) / $cardCols)
$totalWidth = ($cardCols * $cardW) + (($cardCols - 1) * $gapX) + ($padding * 2)
$totalHeight = $headerH + ($rows * $cardH) + ([Math]::Max(0, $rows - 1) * $gapY) + ($padding * 2)

$bitmap = New-Object System.Drawing.Bitmap($totalWidth, $totalHeight)
$bitmap.SetResolution(120, 120)
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::FromArgb(208, 208, 208))

$titleFont = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$sectionFont = New-Object System.Drawing.Font("Segoe UI", 10)
$hexFont = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
$rgbFont = New-Object System.Drawing.Font("Consolas", 7)
$penBlue = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(32, 64, 255), 2)
$penDivider = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 120, 120), 1)
$brushBlack = [System.Drawing.Brushes]::Black
$brushGray = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 90, 90))

$g.DrawString($data.name, $titleFont, $brushBlack, $padding, 20)

$index = 0
foreach ($sectionName in $sectionNames) {
    $row = [Math]::Floor($index / $cardCols)
    $col = $index % $cardCols
    $cardX = $padding + ($col * ($cardW + $gapX))
    $cardY = $headerH + $padding + ($row * ($cardH + $gapY))

    $sectionColors = $groups[$sectionName]
    if (-not $sectionColors) {
        $sectionColors = @()
    }

    if ($sectionColors.Count -eq 0) {
        $g.DrawString("No colors in this section", $rgbFont, $brushGray, $cardX + 12, $cardY + 100)
    } else {
        Draw-RoleBoard $g $sectionColors $cardX $cardY $penBlue $hexFont $rgbFont $sectionFont $penDivider
    }

    $sectionLabelY = $cardY + 178
    $g.DrawString("Section: " + $sectionName, $sectionFont, $brushBlack, $cardX + 12, $sectionLabelY)
    $g.DrawLine($penDivider, $cardX, $sectionLabelY + 20, $cardX + $cardW - 20, $sectionLabelY + 20)

    $index++
}

$bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$penBlue.Dispose()
$penDivider.Dispose()
$brushGray.Dispose()
$titleFont.Dispose()
$sectionFont.Dispose()
$hexFont.Dispose()
$rgbFont.Dispose()
$g.Dispose()
$bitmap.Dispose()
