param(
    [string]$ProjectRoot = "E:\AI Projects\games\haptic fish"
)

Add-Type -AssemblyName System.Drawing
$input = Join-Path $ProjectRoot 'art\ui_v1\runtime_source\rod-bend-strip-v01.png'
$output = Join-Path $ProjectRoot 'art\ui_v1\runtime_source\rod-bend-repacked-v02.png'
$metadata = Join-Path $ProjectRoot 'tools\rod_atlas_v02_metadata.json'
$source = [System.Drawing.Bitmap]::new($input)
$width = $source.Width; $height = $source.Height
$labels = New-Object 'int[]' ($width * $height)
$queue = [System.Collections.Generic.Queue[int]]::new(); $components = [System.Collections.Generic.List[object]]::new(); $id = 0
$neighbors = @(@(1,0), @(-1,0), @(0,1), @(0,-1), @(1,1), @(1,-1), @(-1,1), @(-1,-1))
for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        $start = $y * $width + $x
        if ($labels[$start] -ne 0 -or $source.GetPixel($x,$y).A -lt 8) { continue }
        $id++; $labels[$start] = $id; $queue.Enqueue($start); $count=0; $left=$x; $right=$x; $top=$y; $bottom=$y
        while ($queue.Count -gt 0) {
            $index=$queue.Dequeue(); $cx=$index % $width; $cy=[Math]::Floor($index/$width); $count++; $left=[Math]::Min($left,$cx);$right=[Math]::Max($right,$cx);$top=[Math]::Min($top,$cy);$bottom=[Math]::Max($bottom,$cy)
            foreach($d in $neighbors){$nx=$cx+$d[0];$ny=$cy+$d[1];if($nx -lt 0 -or $ny -lt 0 -or $nx -ge $width -or $ny -ge $height){continue};$next=$ny*$width+$nx;if($labels[$next] -eq 0 -and $source.GetPixel($nx,$ny).A -ge 8){$labels[$next]=$id;$queue.Enqueue($next)}}
        }
        $components.Add([pscustomobject]@{Id=$id;Count=$count;Left=$left;Right=$right;Top=$top;Bottom=$bottom;CenterX=(($left+$right)/2.0)})
    }
}
$rods=@($components|Sort-Object Count -Descending|Select-Object -First 3|Sort-Object CenterX)
if($rods.Count -ne 3){throw "Expected three dominant rod components; found $($rods.Count)"}
$atlas=[System.Drawing.Bitmap]::new(1536,1024,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$g=[System.Drawing.Graphics]::FromImage($atlas);$g.Clear([System.Drawing.Color]::FromArgb(0,255,255,255));$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$sourceTips=@([System.Drawing.Point]::new(467,15),[System.Drawing.Point]::new(461,36),[System.Drawing.Point]::new(1436,94));$tips=@()
for($frame=0;$frame -lt 3;$frame++){
    $rod=$rods[$frame];$cropWidth=$rod.Right-$rod.Left+1;$cropHeight=$rod.Bottom-$rod.Top+1;$crop=[System.Drawing.Bitmap]::new($cropWidth,$cropHeight,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for($cy=0;$cy -lt $cropHeight;$cy++){for($cx=0;$cx -lt $cropWidth;$cx++){if($labels[($rod.Top+$cy)*$width+$rod.Left+$cx] -eq $rod.Id){$crop.SetPixel($cx,$cy,$source.GetPixel($rod.Left+$cx,$rod.Top+$cy))}}}
    $scale=[Math]::Min(480.0/$cropWidth,980.0/$cropHeight);$drawWidth=[int][Math]::Round($cropWidth*$scale);$drawHeight=[int][Math]::Round($cropHeight*$scale);$dx=$frame*512+[int][Math]::Round((512-$drawWidth)/2.0);$dy=[int][Math]::Round((1024-$drawHeight)/2.0);$g.DrawImage($crop,[System.Drawing.Rectangle]::new($dx,$dy,$drawWidth,$drawHeight));$crop.Dispose()
    $tip=$sourceTips[$frame];$tips += [pscustomobject]@{x=[Math]::Round($dx+($tip.X-$rod.Left)*$scale,2);y=[Math]::Round($dy+($tip.Y-$rod.Top)*$scale,2)}
}
$g.Dispose();$atlas.Save($output,[System.Drawing.Imaging.ImageFormat]::Png)
$result=[pscustomobject]@{version=2;cell_size=@(512,1024);tip_anchors=$tips}|ConvertTo-Json -Depth 3
[System.IO.File]::WriteAllText($metadata,$result)
foreach($x in @(511,512,1023,1024)){for($y=0;$y -lt 1024;$y+=16){if($atlas.GetPixel($x,$y).A -ne 0){throw "Nontransparent cell boundary x=$x"}}}
$atlas.Dispose();$source.Dispose()
