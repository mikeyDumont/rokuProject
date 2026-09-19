Add-Type -AssemblyName System.Drawing

$imagesDir = Join-Path $PSScriptRoot "..\images"

function Resize-Image {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [int]$NewWidth,
        [int]$NewHeight
    )

    if (-not (Test-Path $SourcePath)) {
        Write-Error "Source image not found: $SourcePath"
        return
    }

    $srcBmp = [System.Drawing.Image]::FromFile($SourcePath)
    $destBmp = New-Object System.Drawing.Bitmap $NewWidth, $NewHeight
    $g = [System.Drawing.Graphics]::FromImage($destBmp)

    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    # Draw the company logo stretched/fitted to destination dimensions
    $g.DrawImage($srcBmp, 0, 0, $NewWidth, $NewHeight)

    $g.Dispose()
    $srcBmp.Dispose()

    # Overwrite/save the resized company logo image
    $destBmp.Save($TargetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()

    Write-Output "Successfully resized company logo: $TargetPath ($NewWidth x $NewHeight)"
}

# Resize FHD icon (540x303) and SD icon (216x144) from existing company logo
# Resize FHD icon (540x303), HD icon (290x210), and SD icon (246x140) from existing company logo
$fhdPath = Join-Path $imagesDir "icon_focus_fhd.png"
$hdPath  = Join-Path $imagesDir "icon_focus_hd.png"
$sdPath  = Join-Path $imagesDir "icon_focus_sd.png"

Resize-Image -SourcePath $fhdPath -TargetPath $fhdPath -NewWidth 540 -NewHeight 303
Resize-Image -SourcePath $sdPath  -TargetPath $sdPath  -NewWidth 216 -NewHeight 144
Resize-Image -SourcePath $hdPath  -TargetPath $hdPath  -NewWidth 290 -NewHeight 210
Resize-Image -SourcePath $sdPath  -TargetPath $sdPath  -NewWidth 246 -NewHeight 140

