param(
    [string]$ProjectRoot = "E:\AI Projects\games\haptic fish"
)

Add-Type -AssemblyName System.Drawing

function Convert-MatteToAtlas {
    param([string]$InputPath, [string]$OutputPath)
    $source = [System.Drawing.Bitmap]::new($InputPath)
    $matteRemoved = [System.Drawing.Bitmap]::new($source.Width, $source.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($matteRemoved)
    $graphics.DrawImageUnscaled($source, 0, 0)
    $graphics.Dispose(); $source.Dispose()

    $width = $matteRemoved.Width; $height = $matteRemoved.Height
    $visited = New-Object 'bool[]' ($width * $height)
    $queue = [System.Collections.Generic.Queue[int]]::new()
    function Is-Matte([System.Drawing.Color]$Color) {
        return $Color.R -ge 232 -and $Color.G -ge 232 -and $Color.B -ge 232 -and ([Math]::Max($Color.R, [Math]::Max($Color.G, $Color.B)) - [Math]::Min($Color.R, [Math]::Min($Color.G, $Color.B))) -le 18
    }
    function Enqueue-Edge([int]$X, [int]$Y) {
        $index = $Y * $width + $X
        if (-not $visited[$index] -and (Is-Matte $matteRemoved.GetPixel($X, $Y))) { $visited[$index] = $true; $queue.Enqueue($index) }
    }
    for ($x = 0; $x -lt $width; $x++) { Enqueue-Edge $x 0; Enqueue-Edge $x ($height - 1) }
    for ($y = 1; $y -lt ($height - 1); $y++) { Enqueue-Edge 0 $y; Enqueue-Edge ($width - 1) $y }
    $directions = @(@(1,0), @(-1,0), @(0,1), @(0,-1))
    while ($queue.Count -gt 0) {
        $index = $queue.Dequeue(); $x = $index % $width; $y = [Math]::Floor($index / $width)
        $matteRemoved.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 255, 255, 255))
        foreach ($direction in $directions) {
            $nextX = $x + $direction[0]; $nextY = $y + $direction[1]
            if ($nextX -lt 0 -or $nextY -lt 0 -or $nextX -ge $width -or $nextY -ge $height) { continue }
            $nextIndex = $nextY * $width + $nextX
            if (-not $visited[$nextIndex] -and (Is-Matte $matteRemoved.GetPixel($nextX, $nextY))) { $visited[$nextIndex] = $true; $queue.Enqueue($nextIndex) }
        }
    }

    # Repack the three dominant fish components; source row boundaries are not trusted.
    $labels = New-Object 'int[]' ($width * $height)
    $components = [System.Collections.Generic.List[object]]::new()
    $componentId = 0
    $neighbors = @(@(1,0), @(-1,0), @(0,1), @(0,-1), @(1,1), @(1,-1), @(-1,1), @(-1,-1))
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $start = $y * $width + $x
            if ($labels[$start] -ne 0 -or $matteRemoved.GetPixel($x, $y).A -lt 16) { continue }
            $componentId++; $queue.Enqueue($start); $labels[$start] = $componentId
            $count = 0; $left = $x; $right = $x; $top = $y; $bottom = $y
            while ($queue.Count -gt 0) {
                $index = $queue.Dequeue(); $cx = $index % $width; $cy = [Math]::Floor($index / $width)
                $count++; $left = [Math]::Min($left, $cx); $right = [Math]::Max($right, $cx); $top = [Math]::Min($top, $cy); $bottom = [Math]::Max($bottom, $cy)
                foreach ($direction in $neighbors) {
                    $nx = $cx + $direction[0]; $ny = $cy + $direction[1]
                    if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $width -or $ny -ge $height) { continue }
                    $next = $ny * $width + $nx
                    if ($labels[$next] -eq 0 -and $matteRemoved.GetPixel($nx, $ny).A -ge 16) { $labels[$next] = $componentId; $queue.Enqueue($next) }
                }
            }
            $components.Add([pscustomobject]@{ Id=$componentId; Count=$count; Left=$left; Right=$right; Top=$top; Bottom=$bottom; CenterY=(($top + $bottom) / 2.0) })
        }
    }
    $fish = @($components | Sort-Object Count -Descending | Select-Object -First 3 | Sort-Object CenterY)
    if ($fish.Count -ne 3) { throw "Expected three dominant fish components in $InputPath; found $($fish.Count)" }

    $atlas = [System.Drawing.Bitmap]::new(1024, 1536, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $atlasGraphics = [System.Drawing.Graphics]::FromImage($atlas)
    $atlasGraphics.Clear([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
    $atlasGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $atlasGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    for ($row = 0; $row -lt 3; $row++) {
        $component = $fish[$row]
        $cropLeft = [Math]::Max(0, $component.Left - 2); $cropTop = [Math]::Max(0, $component.Top - 2)
        $cropWidth = [Math]::Min($width - $cropLeft, $component.Right - $component.Left + 5); $cropHeight = [Math]::Min($height - $cropTop, $component.Bottom - $component.Top + 5)
        $crop = [System.Drawing.Bitmap]::new($cropWidth, $cropHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        for ($cy = 0; $cy -lt $cropHeight; $cy++) { for ($cx = 0; $cx -lt $cropWidth; $cx++) { $crop.SetPixel($cx, $cy, $matteRemoved.GetPixel($cropLeft + $cx, $cropTop + $cy)) } }
        $scale = [Math]::Min(960.0 / $cropWidth, 440.0 / $cropHeight)
        $drawWidth = [Math]::Max(1, [int][Math]::Round($cropWidth * $scale)); $drawHeight = [Math]::Max(1, [int][Math]::Round($cropHeight * $scale))
        $destination = [System.Drawing.Rectangle]::new([int][Math]::Round((1024 - $drawWidth) / 2.0), $row * 512 + [int][Math]::Round((512 - $drawHeight) / 2.0), $drawWidth, $drawHeight)
        $atlasGraphics.DrawImage($crop, $destination)
        $crop.Dispose()
    }
    $atlasGraphics.Dispose(); $matteRemoved.Dispose()
    $directory = Split-Path -Parent $OutputPath; [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $atlas.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    foreach ($boundary in @(0, 511, 512, 1023, 1024, 1535)) { if ($atlas.GetPixel(0, $boundary).A -ne 0) { throw "Expected transparent atlas boundary at y=$boundary" } }
    foreach ($row in 0..2) {
        $visible = $false
        for ($y = $row * 512 + 24; $y -lt ($row + 1) * 512 - 24 -and -not $visible; $y += 8) { for ($x = 0; $x -lt 1024; $x += 8) { if ($atlas.GetPixel($x, $y).A -gt 0) { $visible = $true; break } } }
        if (-not $visible) { throw "Missing visible fish in atlas row $row" }
    }
    $atlas.Dispose()
}

$mockups = Join-Path $ProjectRoot 'art\ui_v1\mockups'
$runtime = Join-Path $ProjectRoot 'art\ui_v1\runtime_source'
Convert-MatteToAtlas (Join-Path $mockups 'pine-fish-matte-v02.png') (Join-Path $runtime 'pine-fish-atlas-v02.png')
Convert-MatteToAtlas (Join-Path $mockups 'cedar-fish-matte-v02.png') (Join-Path $runtime 'cedar-fish-atlas-v02.png')
