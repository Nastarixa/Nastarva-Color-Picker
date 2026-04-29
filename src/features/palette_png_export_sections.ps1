param(
    [string]$JsonPath,
    [string]$OutPath
)

Add-Type -AssemblyName System.Drawing

$jsonContent = Get-Content $JsonPath -Raw
$data = $jsonContent | ConvertFrom-Json

$showInfo = $false
if ($data.PSObject.Properties.Name -contains "showInfo") {
    $showInfo = $data.showInfo -eq 1
}

$colors = @($data.colors)
$sections = @($data.sections)

# =========================
# LAYOUT CONFIG
# =========================
$cols = if ($data.maxCols) { $data.maxCols } else { 8 }

$cellW = 90
$cellH = 90
$cellGap = 7

$padding = 30
$headerH = 60
$sectionHeaderH = 30
$sectionPadding = 16
$sectionGap = 5

$infoH = if ($showInfo) { 5 } else { 0 }
$rowH = $cellH + $infoH

# =========================
# GROUP COLORS
# =========================
$groups = @{}
foreach ($c in $colors) {
    $sec = if ($c.section) { $c.section } else { "Default" }
    if (-not $groups.ContainsKey($sec)) {
        $groups[$sec] = @()
    }
    $groups[$sec] += $c
}

$orderedSections = @()
foreach ($s in $sections) {
    if ($groups.ContainsKey($s)) { $orderedSections += $s }
}
foreach ($s in $groups.Keys) {
    if ($orderedSections -notcontains $s) { $orderedSections += $s }
}

# =========================
# SIZE CALC
# =========================
$totalWidth = ($cols * $cellW) + (($cols - 1) * $cellGap) + ($padding * 2)

$totalHeight = $headerH + $padding

foreach ($sec in $orderedSections) {
    $count = $groups[$sec].Count
    $rows = [Math]::Ceiling($count / $cols)
    if ($rows -lt 1) { $rows = 1 }

    $secH = $sectionHeaderH +
            ($rows * $rowH) +
            (($rows - 1) * $cellGap) +
            ($sectionPadding * 2)

    $totalHeight += $secH + $sectionGap
}

$totalHeight += $padding

# =========================
# CANVAS
    # =========================
    $bmp = New-Object System.Drawing.Bitmap($totalWidth, $totalHeight)
    $bmp.SetResolution(120, 120)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = "None"
$g.TextRenderingHint = "ClearTypeGridFit"

# Background (soft gray)
$bgColor = [System.Drawing.Color]::FromArgb(245,245,247)
$g.Clear($bgColor)

# =========================
# STYLES
# =========================
$fontTitle   = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$fontSection = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontHex     = New-Object System.Drawing.Font("Consolas", 8)
$fontMeta    = New-Object System.Drawing.Font("Segoe UI", 7)

$brushText   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40,40,40))
$brushSubtle = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120,120,120))

$penBorder   = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(210,210,210), 1)

# =========================
# HELPERS
# =========================
function HexToColor($hex) {
    if ($hex -notmatch '^[0-9A-Fa-f]{6}$') { return $null }
    $r = [Convert]::ToInt32($hex.Substring(0,2),16)
    $g = [Convert]::ToInt32($hex.Substring(2,2),16)
    $b = [Convert]::ToInt32($hex.Substring(4,2),16)
    return [System.Drawing.Color]::FromArgb(255,$r,$g,$b)
}

function GetTextBrush($hex) {
    $c = HexToColor $hex
    if (!$c) { return $brushText }

    $brightness = ($c.R*299 + $c.G*587 + $c.B*114) / 1000
    if ($brightness -lt 140) {
        return [System.Drawing.Brushes]::White
    }
    return [System.Drawing.Brushes]::Black
}

# =========================
# TITLE
# =========================
$g.DrawString($data.name, $fontTitle, $brushText, $padding, 12)

$y = $headerH

# =========================
# DRAW SECTIONS
# =========================
foreach ($sec in $orderedSections) {

    $secColors = $groups[$sec]
    $count = $secColors.Count
    $rows = [Math]::Ceiling($count / $cols)
    if ($rows -lt 1) { $rows = 1 }

    $secHeight = $sectionHeaderH +
                 ($rows * $rowH) +
                 (($rows - 1) * $cellGap) +
                 ($sectionPadding * 2)

    # --- section card background ---
    $cardRect = New-Object System.Drawing.Rectangle($padding, $y, $totalWidth - ($padding*2), $secHeight)
    $cardBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.FillRectangle($cardBrush, $cardRect)
    $g.DrawRectangle($penBorder, $cardRect)
    $cardBrush.Dispose()

    # --- section title ---
    $g.DrawString($sec, $fontSection, $brushText, $padding + 12, $y + 6)

    # --- grid start ---
    $gx = $padding + $sectionPadding
    $gy = $y + $sectionHeaderH

    $x = $gx
    $rowIndex = 0

    for ($i = 0; $i -lt $count; $i++) {

        if ($i -gt 0 -and $i % $cols -eq 0) {
            $x = $gx
            $rowIndex++
        }

        $cy = $gy + ($rowIndex * ($rowH + $cellGap))
        $color = $secColors[$i]
        $hex = $color.hex

        $c = HexToColor $hex
        if ($c) {

            $brush = New-Object System.Drawing.SolidBrush($c)
            $g.FillRectangle($brush, $x, $cy, $cellW, $cellH)
            $g.DrawRectangle($penBorder, $x, $cy, $cellW, $cellH)
            $brush.Dispose()

            if ($showInfo) {
                $textBrush = GetTextBrush $hex

                    # HEX (top)
                    $g.DrawString("#" + $hex.ToUpper(), $fontHex, $textBrush, $x + 6, $cy + 6)

                    # RGB (middle)
                    $rgbText = $color.rgb
                    if (-not $rgbText) {
                        $rgbText = "rgb($($c.R), $($c.G), $($c.B))"
                    }
                    $g.DrawString($rgbText, $fontMeta, $textBrush, $x + 6, $cy + 20)

                    # ROLE (bottom)
                    $g.DrawString($color.role, $fontMeta, $textBrush, $x + 6, $cy + 35)
            }
        }

        $x += $cellW + $cellGap
    }

    $y += $secHeight + $sectionGap
}

# =========================
# SAVE
# =========================
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()

