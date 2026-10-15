. (Join-Path $PSScriptRoot "HSBrandImage.ps1")

$imagesDir = Join-Path $PSScriptRoot "..\images"

# Channel tile icons: HS logo with the HostSync TV name beneath it.
New-HSBrandImage -Path (Join-Path $imagesDir "icon_focus_fhd.png") -Width 540 -Height 303 -LogoScale 0.88 -Caption "HostSync TV"
New-HSBrandImage -Path (Join-Path $imagesDir "icon_focus_hd.png") -Width 336 -Height 210 -LogoScale 0.88 -Caption "HostSync TV"
New-HSBrandImage -Path (Join-Path $imagesDir "icon_focus_sd.png") -Width 246 -Height 140 -LogoScale 0.88 -Caption "HostSync TV"
