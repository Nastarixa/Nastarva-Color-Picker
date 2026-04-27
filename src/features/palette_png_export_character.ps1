param(
    [string]$JsonPath,
    [string]$OutPath
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$data = Get-Content $JsonPath -Raw | ConvertFrom-Json

$showInfo = if ($data.showInfo -eq 1) { $true } else { $false }
$cellSize = 80
$cellGap = 6
$headerH = 40
$cols = 6
$padding = 30
$infoH = if ($showInfo) { 20 } else { 0 }

$colors = $data.colors
$roleGroups = @{}
foreach ($color in $colors) {
    $role = if ($color.role) { $color.role } else { "Other" }
    if (-not $roleGroups.ContainsKey($role)) {
        $roleGroups[$role] = @()
    }
    $roleGroups[$role] += $color
}

$roleOrder = @("Base","Shadow","Highlight","Hi Shadow","2 Shadow","3 Shadow","Mask","Outline","Black","Other")
$sortedRoles = @()
foreach ($role in $roleOrder) {
    if ($roleGroups.ContainsKey($role)) {
        $sortedRoles += $role
    }
}
foreach ($role in $roleGroups.Keys) {
    if ($role -notin $sortedRoles) {
        $sortedRoles += $role
    }
}

$totalRows = 0
foreach ($role in $sortedRoles) {
    $rows = [Math]::Ceiling($roleGroups[$role].Count / $cols)
    if ($rows -eq 0) { $rows = 1 }
    $totalRows += $rows
}

$rowH = $cellSize + $infoH
$totalHeight = $headerH + $padding + ($totalRows * ($rowH + $cellGap)) + ($sortedRoles.Count * 30) + $padding + 20
$totalWidth = ($cellSize + $cellGap) * $cols + $cellGap + $padding * 2

$bitmap = New-Object System.Drawing.Bitmap($totalWidth, $totalHeight)
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::White)

$titleFont = New-Object System.Drawing.Font("Consolas", 14, [System.Drawing.FontStyle]::Bold)
$labelFont = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$infoFont = New-Object System.Drawing.Font("Consolas", 8)
$brushDark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 45, 45))
$brushGold = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 140, 90))
$brushGray = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 100, 100))
$brushHeader = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 45, 45))

$g.FillRectangle($brushHeader, 0, 0, $totalWidth, $headerH)
$g.DrawString($data.name, $titleFont, [System.Drawing.Brushes]::White, $padding, 8)

$y = $headerH + $padding

foreach ($role in $sortedRoles) {
    $g.DrawString($role, $labelFont, $brushDark, $padding, $y)
    $y += 22

    $roleColors = $roleGroups[$role]
    $x = $padding
    $count = 0

    foreach ($color in $roleColors) {
        if ($count -gt 0 -and $count % $cols -eq 0) {
            $x = $padding
            $y += $rowH + $cellGap
        }

        $r = [Convert]::ToInt32($color.hex.Substring(0,2), 16)
        $gr = [Convert]::ToInt32($color.hex.Substring(2,2), 16)
        $b = [Convert]::ToInt32($color.hex.Substring(4,2), 16)
        $c = [System.Drawing.Color]::FromArgb(255, $r, $gr, $b)

        $rect = New-Object System.Drawing.Rectangle($x, $y, $cellSize, $cellSize)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush($c)), $rect)
        $g.DrawRectangle([System.Drawing.Pens]::LightGray, $rect)

        if ($showInfo) {
            $infoY = $y + $cellSize + 2
            $hexText = "#" + $color.hex
            $g.DrawString($hexText, $infoFont, $brushDark, $x, $infoY)
            $infoY += 9
            $rgbText = "$r,$gr,$b"
            $g.DrawString($rgbText, $infoFont, $brushGray, $x, $infoY)
        }

        $x += $cellSize + $cellGap
        $count++
    }

    $y += $rowH + $cellGap + 10
}

$bitmap.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bitmap.Dispose()