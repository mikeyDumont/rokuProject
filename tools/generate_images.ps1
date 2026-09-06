Add-Type -AssemblyName System.Drawing

$imagesDir = Join-Path $PSScriptRoot "..\images"
New-Item -ItemType Directory -Force -Path $imagesDir | Out-Null

# Brand palette
$colBgTop      = [System.Drawing.Color]::FromArgb(255, 20, 36, 28)
$colBgBottom   = [System.Drawing.Color]::FromArgb(255, 9, 16, 12)
$colVignette   = [System.Drawing.Color]::FromArgb(140, 0, 0, 0)
$colMountainBack  = [System.Drawing.Color]::FromArgb(255, 15, 30, 23)
$colMountainFront = [System.Drawing.Color]::FromArgb(255, 22, 43, 33)
$colEmeraldLight  = [System.Drawing.Color]::FromArgb(255, 110, 231, 183)
$colEmeraldMid    = [System.Drawing.Color]::FromArgb(255, 52, 211, 153)
$colEmeraldDark   = [System.Drawing.Color]::FromArgb(255, 15, 81, 50)
$colTrunk         = [System.Drawing.Color]::FromArgb(255, 96, 68, 48)
$colGold          = [System.Drawing.Color]::FromArgb(255, 251, 191, 36)
$colWhite         = [System.Drawing.Color]::FromArgb(255, 246, 250, 248)
$colMuted         = [System.Drawing.Color]::FromArgb(255, 156, 178, 168)

function Paint-Background {
    param($g, [int]$w, [int]$h, [bool]$withStars)

    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $colBgTop, $colBgBottom, 90
    $g.FillRectangle($bgBrush, $rect)
    $bgBrush.Dispose()

    # Soft vignette so edges recede and the emblem/wordmark pop in the center
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(-[int]($w*0.35), -[int]($h*0.5), [int]($w*1.7), [int]($h*2.0))
    $vignetteBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
    $vignetteBrush.CenterColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    $vignetteBrush.SurroundColors = @($colVignette)
    $g.FillRectangle($vignetteBrush, $rect)
    $vignetteBrush.Dispose()
    $path.Dispose()

    if ($withStars) {
        $rnd = New-Object System.Random 42
        $starBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 255, 255, 255))
        for ($i = 0; $i -lt [int]($w * $h / 9000); $i++) {
            $sx = $rnd.Next(0, $w)
            $sy = $rnd.Next(0, [int]($h * 0.55))
            $sr = $rnd.Next(1, 3)
            $g.FillEllipse($starBrush, $sx, $sy, $sr, $sr)
        }
        $starBrush.Dispose()
    }
}

function Paint-Mountains {
    param($g, [int]$w, [int]$h)

    $baseY = [int]($h * 0.86)

    $back = New-Object System.Drawing.Drawing2D.GraphicsPath
    $backPts = @(
        (New-Object System.Drawing.Point 0, $baseY),
        (New-Object System.Drawing.Point ([int]($w*0.16)), ([int]($h*0.62))),
        (New-Object System.Drawing.Point ([int]($w*0.34)), ([int]($h*0.78))),
        (New-Object System.Drawing.Point ([int]($w*0.52)), ([int]($h*0.58))),
        (New-Object System.Drawing.Point ([int]($w*0.74)), ([int]($h*0.80))),
        (New-Object System.Drawing.Point ([int]($w*0.90)), ([int]($h*0.64))),
        (New-Object System.Drawing.Point $w, $baseY)
    )
    $back.AddPolygon($backPts)
    $backBrush = New-Object System.Drawing.SolidBrush $colMountainBack
    $g.FillPath($backBrush, $back)
    $backBrush.Dispose()
    $back.Dispose()

    $front = New-Object System.Drawing.Drawing2D.GraphicsPath
    $frontPts = @(
        (New-Object System.Drawing.Point 0, $h),
        (New-Object System.Drawing.Point 0, ([int]($h*0.92))),
        (New-Object System.Drawing.Point ([int]($w*0.22)), ([int]($h*0.72))),
        (New-Object System.Drawing.Point ([int]($w*0.40)), ([int]($h*0.90))),
        (New-Object System.Drawing.Point ([int]($w*0.60)), ([int]($h*0.70))),
        (New-Object System.Drawing.Point ([int]($w*0.80)), ([int]($h*0.92))),
        (New-Object System.Drawing.Point $w, ([int]($h*0.80))),
        (New-Object System.Drawing.Point $w, $h)
    )
    $front.AddPolygon($frontPts)
    $frontBrush = New-Object System.Drawing.SolidBrush $colMountainFront
    $g.FillPath($frontBrush, $front)
    $frontBrush.Dispose()
    $front.Dispose()
}

function Add-PineEmblem {
    param($g, [int]$cx, [int]$cy, [int]$treeH)

    $treeW = [int]($treeH * 0.72)
    $tierGap = [int]($treeH * 0.15)
    $outlinePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, 6, 20, 13)), ([Math]::Max(1, [int]($treeH*0.012)))

    # three tapering tiers for a layered, more realistic conifer silhouette
    $tiers = @(
        @{ y = ($cy - $treeH*0.50); w = $treeW*0.42; brush = $colEmeraldLight },
        @{ y = ($cy - $treeH*0.22); w = $treeW*0.70; brush = $colEmeraldMid },
        @{ y = ($cy + $treeH*0.10); w = $treeW*1.00; brush = $colEmeraldDark }
    )

    foreach ($tier in $tiers) {
        $topY = $tier.y
        $botY = $topY + $tierGap * 1.7
        $halfW = $tier.w / 2
        $pts = @(
            (New-Object System.Drawing.PointF $cx, $topY),
            (New-Object System.Drawing.PointF ($cx - $halfW), $botY),
            (New-Object System.Drawing.PointF ($cx + $halfW), $botY)
        )
        $brush = New-Object System.Drawing.SolidBrush $tier.brush
        $g.FillPolygon($brush, $pts)
        $g.DrawPolygon($outlinePen, $pts)
        $brush.Dispose()
    }

    $trunkW = $treeW * 0.10
    $trunkH = $treeH * 0.16
    $trunkX = $cx - $trunkW / 2
    $trunkY = $cy + $treeH*0.10 + $tierGap*1.7 - ($treeH*0.02)
    $trunkBrush = New-Object System.Drawing.SolidBrush $colTrunk
    $g.FillRectangle($trunkBrush, $trunkX, $trunkY, $trunkW, $trunkH)
    $trunkBrush.Dispose()
    $outlinePen.Dispose()
}

function Draw-Tracked {
    param($g, [string]$text, $font, $brush, [single]$x, [single]$y, [single]$tracking)

    $curX = $x
    foreach ($ch in $text.ToCharArray()) {
        $g.DrawString([string]$ch, $font, $brush, $curX, $y)
        $size = $g.MeasureString([string]$ch, $font)
        $curX += $size.Width + $tracking
    }
    return $curX - $tracking
}

function Measure-Tracked {
    param($g, [string]$text, $font, [single]$tracking)
    $total = 0.0
    foreach ($ch in $text.ToCharArray()) {
        $size = $g.MeasureString([string]$ch, $font)
        $total += $size.Width + $tracking
    }
    return $total - $tracking
}

function New-IconImage {
    param([string]$Path, [int]$Width, [int]$Height, [bool]$WithWordmark)

    $bmp = New-Object System.Drawing.Bitmap $Width, $Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    Paint-Background -g $g -w $Width -h $Height -withStars ($Height -gt 150)
    Paint-Mountains -g $g -w $Width -h $Height

    $accentBrush = New-Object System.Drawing.SolidBrush $colEmeraldMid
    $barHeight = [Math]::Max(3, [int]($Height * 0.028))
    $g.FillRectangle($accentBrush, 0, $Height - $barHeight, $Width, $barHeight)
    $accentBrush.Dispose()

    $treeH = [int]($Height * 0.56)

    if ($WithWordmark) {
        $cx = [int]($Height * 0.42)
        $cy = [int]($Height * 0.50)
        Add-PineEmblem -g $g -cx $cx -cy $cy -treeH $treeH

        $titleFont = New-Object System.Drawing.Font "Segoe UI", ([Math]::Max(9, [int]($Height*0.080))), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $subFont = New-Object System.Drawing.Font "Segoe UI", ([Math]::Max(7, [int]($Height*0.055))), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $whiteBrush = New-Object System.Drawing.SolidBrush $colWhite
        $goldBrush = New-Object System.Drawing.SolidBrush $colGold

        $textX = $cx + [int]($treeH * 0.48)
        $line1Y = $Height*0.34 - $titleFont.Height/2
        $line2Y = $Height*0.62 - $subFont.Height/2
        Draw-Tracked -g $g -text "BROKEN BOW" -font $titleFont -brush $whiteBrush -x $textX -y $line1Y -tracking 0.5 | Out-Null
        Draw-Tracked -g $g -text "CABINS" -font $subFont -brush $goldBrush -x $textX -y $line2Y -tracking 0.5 | Out-Null

        $titleFont.Dispose(); $subFont.Dispose(); $whiteBrush.Dispose(); $goldBrush.Dispose()
    } else {
        # smallest icon variant: emblem only, centered, for legibility at tiny sizes
        Add-PineEmblem -g $g -cx ([int]($Width/2)) -cy ([int]($Height*0.46)) -treeH ([int]($Height*0.66))
    }

    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "Created $Path ($Width x $Height)"
}

function New-SplashImage {
    param([string]$Path, [int]$Width, [int]$Height)

    $bmp = New-Object System.Drawing.Bitmap $Width, $Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    Paint-Background -g $g -w $Width -h $Height -withStars $true
    Paint-Mountains -g $g -w $Width -h $Height

    $treeH = [int]($Height * 0.30)
    $cx = [int]($Width / 2)
    $cy = [int]($Height * 0.40)
    Add-PineEmblem -g $g -cx $cx -cy $cy -treeH $treeH

    $titleFont = New-Object System.Drawing.Font "Segoe UI", ([int]($Height*0.075)), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $dividerPen = New-Object System.Drawing.Pen $colEmeraldDark, 2
    $subFont = New-Object System.Drawing.Font "Segoe UI", ([int]($Height*0.032)), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $whiteBrush = New-Object System.Drawing.SolidBrush $colWhite
    $mutedBrush = New-Object System.Drawing.SolidBrush $colMuted

    $titleText = "BROKEN BOW"
    $tracking = $Height * 0.006
    $titleWidth = Measure-Tracked -g $g -text $titleText -font $titleFont -tracking $tracking
    $titleY = $cy + $treeH*0.62
    Draw-Tracked -g $g -text $titleText -font $titleFont -brush $whiteBrush -x ($cx - $titleWidth/2) -y $titleY -tracking $tracking | Out-Null

    $dividerY = $titleY + $titleFont.Height + [int]($Height*0.02)
    $dividerW = [int]($Width * 0.10)
    $g.DrawLine($dividerPen, $cx - $dividerW/2, $dividerY, $cx + $dividerW/2, $dividerY)

    $subText = "VACATION CABINS"
    $subSize = $g.MeasureString($subText, $subFont)
    $g.DrawString($subText, $subFont, $mutedBrush, ($cx - $subSize.Width/2), ($dividerY + [int]($Height*0.025)))

    $titleFont.Dispose(); $subFont.Dispose(); $dividerPen.Dispose(); $whiteBrush.Dispose(); $mutedBrush.Dispose()

    $accentBrush = New-Object System.Drawing.SolidBrush $colEmeraldMid
    $barHeight = [Math]::Max(3, [int]($Height * 0.006))
    $g.FillRectangle($accentBrush, 0, $Height - $barHeight, $Width, $barHeight)
    $accentBrush.Dispose()

    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "Created $Path ($Width x $Height)"
}

function New-AppBackgroundImage {
    param([string]$Path, [int]$Width, [int]$Height)

    $bmp = New-Object System.Drawing.Bitmap $Width, $Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $rect = New-Object System.Drawing.Rectangle 0, 0, $Width, $Height
    $topColor = [System.Drawing.Color]::FromArgb(255, 18, 57, 55)
    $bottomColor = [System.Drawing.Color]::FromArgb(255, 7, 22, 24)
    $backgroundBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $topColor, $bottomColor, 55
    $g.FillRectangle($backgroundBrush, $rect)
    $backgroundBrush.Dispose()

    $waterPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $waterPath.AddEllipse(-[int]($Width * 0.20), [int]($Height * 0.40), [int]($Width * 1.20), [int]($Height * 0.75))
    $waterBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush $waterPath
    $waterBrush.CenterColor = [System.Drawing.Color]::FromArgb(85, 69, 164, 180)
    $waterBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 69, 164, 180))
    $g.FillPath($waterBrush, $waterPath)
    $waterBrush.Dispose()
    $waterPath.Dispose()

    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "Created $Path ($Width x $Height)"
}

function New-NavPanelImage {
    param([string]$Path, [int]$Width, [int]$Height)

    $bmp = New-Object System.Drawing.Bitmap $Width, $Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    # Distinct vertical gradient panel (lighter at top, fading to near-black) so the nav rail
    # reads as a fixed menu chrome rather than page content
    $topColor = [System.Drawing.Color]::FromArgb(235, 26, 46, 36)
    $bottomColor = [System.Drawing.Color]::FromArgb(235, 8, 15, 11)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $Width, $Height
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $topColor, $bottomColor, 90
    $g.FillRectangle($bgBrush, $rect)
    $bgBrush.Dispose()

    # thin emerald accent on the right edge separates the menu from the content area
    $accentBrush = New-Object System.Drawing.SolidBrush $colEmeraldMid
    $g.FillRectangle($accentBrush, $Width - 3, 0, 3, $Height)
    $accentBrush.Dispose()

    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "Created $Path ($Width x $Height)"
}

# Channel focus icons (Roku standard sizes)
New-IconImage -Path (Join-Path $imagesDir "icon_focus_sd.png")  -Width 216  -Height 144 -WithWordmark $false
New-IconImage -Path (Join-Path $imagesDir "icon_focus_hd.png")  -Width 336  -Height 210 -WithWordmark $true
New-IconImage -Path (Join-Path $imagesDir "icon_focus_fhd.png") -Width 540  -Height 303 -WithWordmark $true

# Splash screens
New-SplashImage -Path (Join-Path $imagesDir "splash_hd.png")  -Width 1280 -Height 720
New-SplashImage -Path (Join-Path $imagesDir "splash_fhd.png") -Width 1920 -Height 1080

New-AppBackgroundImage -Path (Join-Path $imagesDir "app_background_fhd.png") -Width 1920 -Height 1080

# Nav rail background panel (wider than the 280px item column so it has left/right breathing room)
New-NavPanelImage -Path (Join-Path $imagesDir "nav_panel.png") -Width 320 -Height 880


Write-Output "Done"
