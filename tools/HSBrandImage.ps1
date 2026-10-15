Add-Type -AssemblyName System.Drawing

# Shared by generate_images.ps1 and resize_custom_icons.ps1. With -Caption, the logo is
# stacked above the caption; the layout matches the checked-in channel tile images.
function New-HSBrandImage {
    param(
        [string]$Path,
        [int]$Width,
        [int]$Height,
        [double]$LogoScale,
        [string]$Caption = ""
    )

    $sourcePath = Join-Path $PSScriptRoot "..\HS-icon-512.png"
    if (-not (Test-Path $sourcePath)) {
        throw "HS icon source image was not found: $sourcePath"
    }

    $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
    $left = $source.Width
    $top = $source.Height
    $right = 0
    $bottom = 0
    for ($y = 0; $y -lt $source.Height; $y++) {
        for ($x = 0; $x -lt $source.Width; $x++) {
            if ($source.GetPixel($x, $y).A -gt 8) {
                $left = [Math]::Min($left, $x)
                $top = [Math]::Min($top, $y)
                $right = [Math]::Max($right, $x)
                $bottom = [Math]::Max($bottom, $y)
            }
        }
    }
    if ($right -lt $left -or $bottom -lt $top) {
        $source.Dispose()
        throw "HS icon source contains no visible artwork: $sourcePath"
    }

    $sourceRect = New-Object System.Drawing.Rectangle $left, $top, ($right - $left + 1), ($bottom - $top + 1)
    $target = New-Object System.Drawing.Bitmap $Width, $Height
    $graphics = [System.Drawing.Graphics]::FromImage($target)
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 245, 247, 246))
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    if ($Caption -ne "") {
        $fontPath = Join-Path $PSScriptRoot "fonts\Inter-SemiBold.ttf"
        if (-not (Test-Path $fontPath)) {
            $graphics.Dispose()
            $target.Dispose()
            $source.Dispose()
            throw "Caption font was not found: $fontPath"
        }
        $fonts = New-Object System.Drawing.Text.PrivateFontCollection
        $fonts.AddFontFile($fontPath)
        $family = $fonts.Families[0]
        $style = [System.Drawing.FontStyle]::Regular
        if (-not $family.IsStyleAvailable($style)) {
            $style = [System.Drawing.FontStyle]::Bold
        }

        # Glyph outlines give exact ink bounds, so the logo + caption block is centered optically.
        $captionPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $origin = New-Object System.Drawing.PointF 0, 0
        $captionPath.AddString($Caption, $family, [int]$style, [single][Math]::Round($Height * 0.17), $origin, [System.Drawing.StringFormat]::GenericTypographic)
        $textBounds = $captionPath.GetBounds()

        $logoHeight = [int][Math]::Round($Height * 0.58)
        $gap = [int][Math]::Round($Height * 0.045)
        $logoWidth = [Math]::Max(1, [int][Math]::Round($sourceRect.Width * $logoHeight / $sourceRect.Height))
        $logoTop = [int][Math]::Round(($Height - ($logoHeight + $gap + $textBounds.Height)) / 2)
        $destRect = New-Object System.Drawing.Rectangle ([int](($Width - $logoWidth) / 2)), $logoTop, $logoWidth, $logoHeight
        $graphics.DrawImage($source, $destRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)

        $matrix = New-Object System.Drawing.Drawing2D.Matrix
        $matrix.Translate([single]((($Width - $textBounds.Width) / 2) - $textBounds.X), [single](($logoTop + $logoHeight + $gap) - $textBounds.Y))
        $captionPath.Transform($matrix)
        $inkBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 29, 33, 37))
        $graphics.FillPath($inkBrush, $captionPath)

        $inkBrush.Dispose()
        $matrix.Dispose()
        $captionPath.Dispose()
        $fonts.Dispose()
    } else {
        $maxWidth = $Width * $LogoScale
        $maxHeight = $Height * $LogoScale
        $scale = [Math]::Min($maxWidth / $sourceRect.Width, $maxHeight / $sourceRect.Height)
        $logoWidth = [Math]::Max(1, [int]($sourceRect.Width * $scale))
        $logoHeight = [Math]::Max(1, [int]($sourceRect.Height * $scale))
        $destRect = New-Object System.Drawing.Rectangle ([int](($Width - $logoWidth) / 2)), ([int](($Height - $logoHeight) / 2)), $logoWidth, $logoHeight
        $graphics.DrawImage($source, $destRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    }

    $graphics.Dispose()
    $source.Dispose()
    $target.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $target.Dispose()
    Write-Output "Created $Path ($Width x $Height)"
}
