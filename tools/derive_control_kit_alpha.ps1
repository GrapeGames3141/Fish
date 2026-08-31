param(
    [string]$ProjectRoot = "E:\AI Projects\games\haptic fish"
)

Add-Type -AssemblyName System.Drawing
$input = Join-Path $ProjectRoot 'art\ui_v1\mockups\control-kit-matte-v01.png'
$outputDirectory = Join-Path $ProjectRoot 'art\ui_v1\runtime'
$output = Join-Path $outputDirectory 'control-kit-alpha-v01.png'
$source = [System.Drawing.Bitmap]::new($input)
$bitmap = [System.Drawing.Bitmap]::new($source.Width, $source.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap); $graphics.DrawImageUnscaled($source, 0, 0); $graphics.Dispose(); $source.Dispose()
$width = $bitmap.Width; $height = $bitmap.Height
$visited = New-Object 'bool[]' ($width * $height)
$queue = [System.Collections.Generic.Queue[int]]::new()
function Is-Matte([System.Drawing.Color]$Color) { return $Color.R -ge 232 -and $Color.G -ge 232 -and $Color.B -ge 232 -and ([Math]::Max($Color.R, [Math]::Max($Color.G, $Color.B)) - [Math]::Min($Color.R, [Math]::Min($Color.G, $Color.B))) -le 18 }
function Enqueue-Edge([int]$X, [int]$Y) { $index = $Y * $width + $X; if (-not $visited[$index] -and (Is-Matte $bitmap.GetPixel($X, $Y))) { $visited[$index] = $true; $queue.Enqueue($index) } }
for ($x = 0; $x -lt $width; $x++) { Enqueue-Edge $x 0; Enqueue-Edge $x ($height - 1) }
for ($y = 1; $y -lt ($height - 1); $y++) { Enqueue-Edge 0 $y; Enqueue-Edge ($width - 1) $y }
while ($queue.Count -gt 0) {
    $index = $queue.Dequeue(); $x = $index % $width; $y = [Math]::Floor($index / $width)
    $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 255, 255, 255))
    foreach ($direction in @(@(1,0), @(-1,0), @(0,1), @(0,-1))) {
        $nx = $x + $direction[0]; $ny = $y + $direction[1]
        if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $width -or $ny -ge $height) { continue }
        $next = $ny * $width + $nx
        if (-not $visited[$next] -and (Is-Matte $bitmap.GetPixel($nx, $ny))) { $visited[$next] = $true; $queue.Enqueue($next) }
    }
}
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
$bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
if ($bitmap.GetPixel(0, 0).A -ne 0) { throw "Control kit corner is not transparent" }
$bitmap.Dispose()
