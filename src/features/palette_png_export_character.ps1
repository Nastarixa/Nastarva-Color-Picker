param(
    [string]$JsonPath,
    [string]$OutPath
)

try {
    Add-Type -AssemblyName System.Drawing

    $jsonContent = Get-Content $JsonPath -Raw -ErrorAction Stop
    $data = $jsonContent | ConvertFrom-Json -ErrorAction Stop

    $showInfo = $false
    if ($data.PSObject.Properties.Name -contains "showInfo") {
        $showInfo = $data.showInfo -ne 0
    }

    $colors = @($data.colors)

    # =========================
    # LAYOUT CONFIG
    # =========================
    $cardW = 350
    $cardH = 200
    $gapX = 20
    $gapY = 20
    $padding = 40
    $cols = 4

    # =========================
    # GROUP COLORS
    # =========================
    $groups = @{}

    foreach ($c in $colors) {
        $sec = $c.section
        if (!$sec) { $sec = "Default" }

        $role = $c.role
        if (!$role) { $role = "Base" }

        $role = $role.Trim()
        if ($role -match '^BL$') { $role = "Black" }
        if ($role -match 'Hi[\s-]*Shadow|High[\s-]*Shadow') { $role = "Hi Shadow" }
        if ($role -match "2.*Shadow|Shadow.*2|Second Shadow") { $role = "2 Shadow" }

        if (-not $groups.ContainsKey($sec)) {
            $groups[$sec] = @{}
        }

        $groups[$sec][$role] = $c
    }

    $orderedSections = @($data.sections | Where-Object { $groups.ContainsKey($_)})
    if (-not $orderedSections) {
        $orderedSections = $groups.Keys | Sort-Object
    }

    $rows = [math]::Ceiling($orderedSections.Count / $cols)

    $totalWidth  = ($cardW * $cols) + ($gapX * ($cols - 1)) + ($padding * 2)
    $totalHeight = ($cardH * $rows) + ($gapY * ($rows - 1)) + ($padding * 2)

    # =========================
    # CANVAS
    # =========================
    $bmp = New-Object System.Drawing.Bitmap($totalWidth, $totalHeight)
    $bmp.SetResolution(120, 120)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "None"
    $g.Clear([System.Drawing.Color]::FromArgb(245,245,245))

    # =========================
    # FONTS
    # =========================
    $fHex = New-Object System.Drawing.Font("Consolas", 6)
    $fTitle = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $fMain = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $fSmall = New-Object System.Drawing.Font("Consolas", 6)
    $fLabel = New-Object System.Drawing.Font("Consolas", 9)

    $brushText = [System.Drawing.Brushes]::Black
    $brushWhite = [System.Drawing.Brushes]::White
    $penBlue = New-Object System.Drawing.Pen([System.Drawing.Color]::Blue, 2)

    # subtle card background
    $cardBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,255,255))
    $cardBorder = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220,220,220),1)

    function HexToColor($hex) {
        if ($hex -notmatch '^[0-9A-Fa-f]{6}$') { return $null }
        $r = [Convert]::ToInt32($hex.Substring(0,2),16)
        $g = [Convert]::ToInt32($hex.Substring(2,2),16)
        $b = [Convert]::ToInt32($hex.Substring(4,2),16)
        return [System.Drawing.Color]::FromArgb(255,$r,$g,$b)
    }

    function GetTextColor($hex) {
        $c = HexToColor $hex
        if (!$c) { return $brushText }
        $brightness = ($c.R * 299 + $c.G * 587 + $c.B * 114) / 1000
        if ($brightness -lt 128) { return $brushWhite }
        return $brushText
    }

    function GetRgbText($hex) {
        $c = HexToColor $hex
        if (!$c) { return "" }
        return "$($c.R), $($c.G), $($c.B)"
    }

    function DrawBlock($g, $x, $y, $w, $h, $hex, $label) {
        $c = HexToColor $hex
        if (!$c) { return }

        $brush = New-Object System.Drawing.SolidBrush($c)
        $g.FillRectangle($brush, $x, $y, $w, $h)
        $g.DrawRectangle($penBlue, $x, $y, $w, $h)

        if ($label) {
            $textBrush = GetTextColor $hex
            $g.DrawString($label, $fLabel, $textBrush, $x + 3, $y + 2)
        }

        $brush.Dispose()
    }

    # =========================
    # TITLE
    # =========================
    $g.DrawString($data.name, $fMain, $brushText, $padding, 5)

    # =========================
    # DRAW SECTIONS
    # =========================
    $i = 0

    foreach ($sec in $orderedSections) {

        $col = $i % $cols
        $row = [math]::Floor($i / $cols)

        $x = $padding + $col * ($cardW + $gapX)
        $y = $padding + $row * ($cardH + $gapY) + 30

        # --- CARD BACKGROUND ---
        $g.FillRectangle($cardBrush, $x-5, $y-5, $cardW, $cardH)
        $g.DrawRectangle($cardBorder, $x-5, $y-5, $cardW, $cardH)

        $group = $groups[$sec]

        # ==== LEFT CLUSTER ====
        $lx = $x + 5
        $ly = $y + 30

        # --- MASK ---
        if ($group["Mask"]) {
            $hex = $group["Mask"].hex

            # TEXT ABOVE
            $g.DrawString("Mask", $fLabel, $brushText, $lx, ($ly + 30) - 18)

            # BLOCK
            DrawBlock $g $lx ($ly + 30) 60 40 $hex ""
        }

        # --- OUTLINE ---
        if ($group["Outline"]) {
            $hex = $group["Outline"].hex

            $g.DrawString("Outline", $fLabel, $brushText, ($lx + 70), $ly - 18)

            DrawBlock $g ($lx + 70) $ly 60 40 $hex ""
        }

        # --- BLACK ---
        if ($group["Black"]) {
            $hex = $group["Black"].hex

            $g.DrawString("BL", $fLabel, $brushText, ($lx + 70), ($ly + 65) - 18)

            DrawBlock $g ($lx + 70) ($ly + 65) 60 40 $hex ""
        }

        # ==== MAIN STACK ====
        $mx = $x + 150
        $cursorY = $y + 28

        foreach ($role in @("Base","Shadow","2 Shadow")) {
            if ($group[$role]) {
                $hex = $group[$role].hex
                DrawBlock $g $mx $cursorY 90 45 $hex

                if ($showInfo) {
                    $textBrush = GetTextColor $hex
                    $g.DrawString("#" + $hex.ToUpper(), $fHex, $textBrush, $mx + 4, $cursorY + 12)
                    $g.DrawString((GetRgbText $hex), $fHex, $textBrush, $mx + 4, $cursorY + 24)
                }

                $cursorY += 46
            }
        }

        # ==== SIDE MINI ====
        $sx = $mx + 90
        $sy = $y + 20

        foreach ($pair in @("Highlight","Hi Shadow")) {
            if ($group[$pair]) {
                $hex = $group[$pair].hex
                DrawBlock $g $sx $sy 25 25 $hex

                if ($showInfo) {
                    $g.DrawString("#" + $hex.ToUpper(), $fSmall, $brushText, $sx + 26, $sy)
                    $g.DrawString((GetRgbText $hex), $fSmall, $brushText, $sx + 26, $sy + 10)
                }

                $sy += 44
            }
        }

        # ==== SECTION LABEL ====
        $g.DrawString($sec, $fTitle, $brushText, $x, $y + 160)
        $g.DrawLine([System.Drawing.Pens]::Gray, $x, $y + 185, $x + $cardW - 10, $y + 185)

        $i++
    }

    # =========================
    # SAVE
    # =========================
    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $g.Dispose()
    $bmp.Dispose()

    $penBlue.Dispose()
    $cardBrush.Dispose()
    $cardBorder.Dispose()

    Write-Host "SUCCESS: $OutPath"

} catch {
    Write-Error $_
    exit 1
}