param(
    [string]$ImagePath,
    [string]$OutPath
)

Add-Type -AssemblyName System.Drawing
try { Add-Type -AssemblyName System.Runtime.WindowsRuntime } catch {}

Add-Type -ReferencedAssemblies @("System.Drawing.dll", "System.dll") @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class PaletteRegion {
    public int X;
    public int Y;
    public int Width;
    public int Height;
    public int Area;
    public int R;
    public int G;
    public int B;
}

public static class PaletteImageDetector {
    private static int Dist(int r1, int g1, int b1, int r2, int g2, int b2) {
        return Math.Abs(r1 - r2) + Math.Abs(g1 - g2) + Math.Abs(b1 - b2);
    }

    public static List<PaletteRegion> Detect(string path) {
        using (var source = new Bitmap(path))
        using (var bmp = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb)) {
            using (var g = Graphics.FromImage(bmp)) {
                g.DrawImage(source, 0, 0, source.Width, source.Height);
            }

            int width = bmp.Width;
            int height = bmp.Height;
            var rect = new Rectangle(0, 0, width, height);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int stride = data.Stride;
            byte[] bytes = new byte[stride * height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            bmp.UnlockBits(data);

            Func<int, int, int> indexAt = (x, y) => y * stride + x * 4;
            int[,] corners = new int[,] {
                { 4, 4 },
                { Math.Max(0, width - 5), 4 },
                { 4, Math.Max(0, height - 5) },
                { Math.Max(0, width - 5), Math.Max(0, height - 5) }
            };

            int bgR = 0, bgG = 0, bgB = 0;
            for (int i = 0; i < 4; i++) {
                int cx = corners[i, 0];
                int cy = corners[i, 1];
                int idx = indexAt(cx, cy);
                bgB += bytes[idx];
                bgG += bytes[idx + 1];
                bgR += bytes[idx + 2];
            }
            bgR /= 4; bgG /= 4; bgB /= 4;

            int bgThreshold = 30;
            int regionTolerance = 24;
            int minArea = Math.Max(120, (width * height) / 2000);
            bool[] visited = new bool[width * height];
            var regions = new List<PaletteRegion>();
            int[] dx = new int[] { 1, -1, 0, 0 };
            int[] dy = new int[] { 0, 0, 1, -1 };

            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    int flat = y * width + x;
                    if (visited[flat]) continue;

                    int idx = indexAt(x, y);
                    int b = bytes[idx];
                    int g = bytes[idx + 1];
                    int r = bytes[idx + 2];
                    if (Dist(r, g, b, bgR, bgG, bgB) < bgThreshold) {
                        visited[flat] = true;
                        continue;
                    }

                    var queue = new Queue<int>();
                    queue.Enqueue(flat);
                    visited[flat] = true;

                    int area = 0, minX = x, maxX = x, minY = y, maxY = y;
                    long sumR = 0, sumG = 0, sumB = 0;

                    while (queue.Count > 0) {
                        int cur = queue.Dequeue();
                        int cx = cur % width;
                        int cy = cur / width;
                        int cidx = indexAt(cx, cy);
                        int cb = bytes[cidx];
                        int cg = bytes[cidx + 1];
                        int cr = bytes[cidx + 2];

                        area++;
                        sumR += cr; sumG += cg; sumB += cb;
                        if (cx < minX) minX = cx;
                        if (cx > maxX) maxX = cx;
                        if (cy < minY) minY = cy;
                        if (cy > maxY) maxY = cy;

                        for (int k = 0; k < 4; k++) {
                            int nx = cx + dx[k];
                            int ny = cy + dy[k];
                            if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;

                            int nflat = ny * width + nx;
                            if (visited[nflat]) continue;
                            int nidx = indexAt(nx, ny);
                            int nb = bytes[nidx];
                            int ng = bytes[nidx + 1];
                            int nr = bytes[nidx + 2];

                            if (Dist(nr, ng, nb, bgR, bgG, bgB) < bgThreshold) {
                                visited[nflat] = true;
                                continue;
                            }

                            if (Dist(nr, ng, nb, r, g, b) <= regionTolerance) {
                                visited[nflat] = true;
                                queue.Enqueue(nflat);
                            }
                        }
                    }

                    int regionWidth = maxX - minX + 1;
                    int regionHeight = maxY - minY + 1;
                    double fillRatio = (double)area / Math.Max(1, regionWidth * regionHeight);
                    double aspect = (double)regionWidth / Math.Max(1, regionHeight);
                    if (
                        area < minArea
                        || regionWidth < 14
                        || regionHeight < 14
                        || fillRatio < 0.72
                        || aspect < 0.45
                        || aspect > 4.0
                    ) {
                        continue;
                    }

                    int sampleX = minX + (regionWidth / 2);
                    int sampleY = minY + (regionHeight / 2);
                    sampleX = Math.Max(minX, Math.Min(maxX, sampleX));
                    sampleY = Math.Max(minY, Math.Min(maxY, sampleY));
                    int sampleIdx = indexAt(sampleX, sampleY);
                    int sampleB = bytes[sampleIdx];
                    int sampleG = bytes[sampleIdx + 1];
                    int sampleR = bytes[sampleIdx + 2];

                    regions.Add(new PaletteRegion {
                        X = minX,
                        Y = minY,
                        Width = regionWidth,
                        Height = regionHeight,
                        Area = area,
                        R = sampleR,
                        G = sampleG,
                        B = sampleB
                    });
                }
            }

            return regions;
        }
    }
}
"@

function Get-RoleSequence {
    param($Items)

    $count = @($Items).Count
    if ($count -le 0) { return @() }
    if ($count -eq 1) { return @("Base") }

    $areas = @($Items | ForEach-Object { [double]$_.Area })
    $maxArea = ($areas | Measure-Object -Maximum).Maximum
    $minArea = ($areas | Measure-Object -Minimum).Minimum
    $hasSmall = ($minArea -lt ($maxArea * 0.70))

    if ($count -eq 2) {
        if ($hasSmall) { return @("Highlight", "Base") }
        return @("Base", "Shadow")
    }

    if ($count -eq 3) {
        if ($hasSmall) { return @("Highlight", "Base", "Shadow") }
        return @("Base", "Shadow", "2 Shadow")
    }

    $roles = @("Highlight", "Base", "Hi Shadow", "Shadow", "2 Shadow")
    while ($roles.Count -lt $count) {
        $roles += "Shadow"
    }
    return $roles
}

function Get-Hex {
    param($R, $G, $B)
    return ('{0:X2}{1:X2}{2:X2}' -f [int]$R, [int]$G, [int]$B)
}

function Await-WinRT {
    param(
        $Operation,
        [Type]$ResultType
    )

    $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } |
        Select-Object -First 1

    if (-not $method) {
        return $null
    }

    $task = $method.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $task.Wait(-1) | Out-Null
    return $task.Result
}

function Get-OcrLines {
    param([string]$Path)

    try {
        [void][Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
        [void][Windows.Storage.FileAccessMode, Windows.Storage, ContentType = WindowsRuntime]
        [void][Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
        [void][Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
        [void][Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType = WindowsRuntime]
    } catch {
        return @()
    }

    try {
        $file = Await-WinRT ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Path)) ([Windows.Storage.StorageFile])
        if (-not $file) { return @() }

        $stream = Await-WinRT ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
        if (-not $stream) { return @() }

        $decoder = Await-WinRT ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
        if (-not $decoder) { return @() }

        $bitmap = Await-WinRT ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
        if (-not $bitmap) { return @() }

        $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
        if (-not $engine) { return @() }

        $result = Await-WinRT ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
        if (-not $result) { return @() }

        $lines = @()
        foreach ($line in $result.Lines) {
            $text = Sanitize-LabelText $line.Text
            if ($text -eq "") {
                continue
            }

            $rect = $line.BoundingRect
            $lines += [pscustomobject]@{
                Text   = $text
                X      = [double]$rect.X
                Y      = [double]$rect.Y
                Width  = [double]$rect.Width
                Height = [double]$rect.Height
            }
        }

        return ,$lines
    } catch {
        return @()
    }
}

function Sanitize-LabelText {
    param([string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    $clean = $Text -replace '[\r\n|]+', ' '
    $clean = $clean -replace '\s{2,}', ' '
    return $clean.Trim()
}

function IsUsefulLabelText {
    param([string]$Text)

    $text = Sanitize-LabelText $Text
    if ($text -eq "") {
        return $false
    }

    $letters = [regex]::Matches($text, '[\p{L}\p{N}]').Count
    $junk = [regex]::Matches($text, '[^ \p{L}\p{N}_\-/]').Count

    if ($letters -lt 2) {
        return $false
    }

    return $junk -le [Math]::Max(1, [int]($text.Length * 0.25))
}

function Get-UniqueSectionName {
    param(
        [string]$Candidate,
        [int]$Index,
        [hashtable]$Used
    )

    $name = Sanitize-LabelText $Candidate
    if (-not (IsUsefulLabelText $name)) {
        $name = "Section $Index"
    }

    $base = $name
    $suffix = 2
    while ($Used.ContainsKey($name)) {
        $name = "$base $suffix"
        $suffix++
    }

    $Used[$name] = $true
    return $name
}

function Get-GroupBounds {
    param($Group)

    return [pscustomobject]@{
        MinX = ($Group | Measure-Object -Property X -Minimum).Minimum
        MaxX = ($Group | ForEach-Object { $_.X + $_.Width } | Measure-Object -Maximum).Maximum
        MinY = ($Group | Measure-Object -Property Y -Minimum).Minimum
        MaxY = ($Group | ForEach-Object { $_.Y + $_.Height } | Measure-Object -Maximum).Maximum
    }
}

function Get-NearestGroupLabel {
    param(
        $Group,
        $OcrLines
    )

    if (@($OcrLines).Count -eq 0) {
        return ""
    }

    $bounds = Get-GroupBounds $Group
    $bestText = ""
    $bestScore = [double]::PositiveInfinity

    foreach ($line in $OcrLines) {
        $lineCenterX = $line.X + ($line.Width / 2.0)
        $lineCenterY = $line.Y + ($line.Height / 2.0)
        $dx = if ($lineCenterX -lt $bounds.MinX) {
            $bounds.MinX - $lineCenterX
        } elseif ($lineCenterX -gt $bounds.MaxX) {
            $lineCenterX - $bounds.MaxX
        } else {
            0
        }
        $dy = if ($lineCenterY -lt $bounds.MinY) {
            $bounds.MinY - $lineCenterY
        } elseif ($lineCenterY -gt $bounds.MaxY) {
            $lineCenterY - $bounds.MaxY
        } else {
            0
        }

        if ($dx -gt 240 -or $dy -gt 140) {
            continue
        }

        $score = ($dx * 1.15) + $dy
        if ($lineCenterY -gt $bounds.MaxY) {
            $score += 160
        }
        if ($lineCenterX -gt $bounds.MaxX + 80) {
            $score += 50
        }

        if ($score -lt $bestScore) {
            $bestScore = $score
            $bestText = $line.Text
        }
    }

    return $bestText
}

function Get-RegionCenter {
    param($Region, [string]$Axis)

    if ($Axis -eq "X") {
        return $Region.X + ($Region.Width / 2.0)
    }

    return $Region.Y + ($Region.Height / 2.0)
}

function Split-IntoGroups {
    param(
        $Items,
        [string]$Axis,
        [double]$Threshold
    )

    $sorted = @($Items | Sort-Object { Get-RegionCenter $_ $Axis })
    $groups = @()
    $current = @()
    $prevCenter = $null

    foreach ($item in $sorted) {
        $center = Get-RegionCenter $item $Axis

        if ($null -ne $prevCenter -and [Math]::Abs($center - $prevCenter) -gt $Threshold -and $current.Count -gt 0) {
            $groups += ,$current
            $current = @()
        }

        $current += $item
        $prevCenter = $center
    }

    if ($current.Count -gt 0) {
        $groups += ,$current
    }

    return ,$groups
}

$regions = [PaletteImageDetector]::Detect($ImagePath)
$regions = @($regions | Sort-Object X, Y)

if ($regions.Count -eq 0) {
    Set-Content -Path $OutPath -Value '' -Encoding UTF8
    exit 0
}

$spreadX = (($regions | Measure-Object -Property X -Maximum).Maximum) - (($regions | Measure-Object -Property X -Minimum).Minimum)
$spreadY = (($regions | Measure-Object -Property Y -Maximum).Maximum) - (($regions | Measure-Object -Property Y -Minimum).Minimum)
$groupByX = ($spreadX -ge $spreadY)
$primaryAxis = if ($groupByX) { "X" } else { "Y" }
$secondaryAxis = if ($groupByX) { "Y" } else { "X" }
$avgPrimarySpan = if ($groupByX) {
    [Math]::Max(18, (($regions | Measure-Object -Property Width -Average).Average))
} else {
    [Math]::Max(18, (($regions | Measure-Object -Property Height -Average).Average))
}
$avgSecondarySpan = if ($groupByX) {
    [Math]::Max(18, (($regions | Measure-Object -Property Height -Average).Average))
} else {
    [Math]::Max(18, (($regions | Measure-Object -Property Width -Average).Average))
}
$primaryThreshold = [Math]::Max(24, [int]($avgPrimarySpan * 1.15))
$secondaryThreshold = [Math]::Max(28, [int]($avgSecondarySpan * 1.8))
$groups = @()

$primaryGroups = Split-IntoGroups $regions $primaryAxis $primaryThreshold
foreach ($primaryGroup in $primaryGroups) {
    $secondaryGroups = Split-IntoGroups @($primaryGroup) $secondaryAxis $secondaryThreshold
    foreach ($secondaryGroup in $secondaryGroups) {
        if (@($secondaryGroup).Count -gt 0) {
            $groups += ,@($secondaryGroup)
        }
    }
}

$groups = @($groups | Sort-Object {
    $g = @($_)
    if ($groupByX) {
        (($g | Measure-Object -Property X -Minimum).Minimum * 10000) + (($g | Measure-Object -Property Y -Minimum).Minimum)
    } else {
        (($g | Measure-Object -Property Y -Minimum).Minimum * 10000) + (($g | Measure-Object -Property X -Minimum).Minimum)
    }
})

$ocrLines = Get-OcrLines $ImagePath
$usedSectionNames = @{}

$lines = New-Object System.Collections.Generic.List[string]

for ($g = 0; $g -lt $groups.Count; $g++) {
    $group = @($groups[$g])
    $sectionName = Get-UniqueSectionName (Get-NearestGroupLabel $group $ocrLines) ($g + 1) $usedSectionNames
    $lines.Add("#SECTION|" + $sectionName)
    $minX = ($group | Measure-Object -Property X -Minimum).Minimum
    $maxX = ($group | ForEach-Object { $_.X + $_.Width } | Measure-Object -Maximum).Maximum
    $minY = ($group | Measure-Object -Property Y -Minimum).Minimum
    $maxY = ($group | ForEach-Object { $_.Y + $_.Height } | Measure-Object -Maximum).Maximum
    $sectionVertical = (($maxY - $minY) -ge ($maxX - $minX))

    if ($sectionVertical) {
        $group = @($group | Sort-Object { $_.Y + ($_.Height / 2.0) }, { $_.X + ($_.Width / 2.0) })
    } else {
        $group = @($group | Sort-Object { $_.X + ($_.Width / 2.0) }, { $_.Y + ($_.Height / 2.0) })
    }

    $roles = @(Get-RoleSequence $group)
    for ($i = 0; $i -lt $group.Count; $i++) {
        $region = $group[$i]
        $role = if ($i -lt $roles.Count) { $roles[$i] } else { "Shadow" }
        $hex = Get-Hex $region.R $region.G $region.B
        $rgb = "$($region.R),$($region.G),$($region.B)"
        $name = Sanitize-LabelText ($sectionName + " " + $role)
        $pinOrder = $i + 1
        $lines.Add($hex + "|" + $rgb + "|" + $name + "|" + $role + "|1|" + $pinOrder + "|" + $sectionName)
    }
}

$dir = Split-Path -Parent $OutPath
if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
}

Set-Content -Path $OutPath -Value $lines -Encoding UTF8
