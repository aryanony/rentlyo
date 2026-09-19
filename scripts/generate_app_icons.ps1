<#
.SYNOPSIS
  Generates production-grade, perfectly proportioned launcher icon assets for Rentlyo Suite.
  Ensures icons are safe-zone compliant (no zooming or cut-off edges) with clean white background.
#>

param(
    [string]$SourceLogoPath = "client_assets\logo.png",
    [int]$CanvasSize = 1024,
    [float]$TargetHeight = 490.0
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
Set-Location $RootDir

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $SourceLogoPath)) {
    if (Test-Path "assets\rentlyo-icon_vectorized.png") {
        $SourceLogoPath = "assets\rentlyo-icon_vectorized.png"
    } elseif (Test-Path "Rentlyo\assets\images\logo.png") {
        $SourceLogoPath = "Rentlyo\assets\images\logo.png"
    } else {
        Write-Error "Source logo file not found!"
        exit 1
    }
}

Write-Host "🎨 Generating Launcher Icon Assets from: $SourceLogoPath" -ForegroundColor Cyan
$srcFullPath = (Resolve-Path $SourceLogoPath).Path
$srcImg = [System.Drawing.Bitmap]::FromFile($srcFullPath)

# 1. Calculate tight bounding box of visible pixels
$minX = $srcImg.Width; $maxX = 0; $minY = $srcImg.Height; $maxY = 0
for ($y = 0; $y -lt $srcImg.Height; $y++) {
    for ($x = 0; $x -lt $srcImg.Width; $x++) {
        $pixel = $srcImg.GetPixel($x, $y)
        if ($pixel.A -gt 15) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

if ($maxX -lt $minX -or $maxY -lt $minY) {
    Write-Error "Logo appears completely transparent or empty."
    $srcImg.Dispose()
    exit 1
}

$cropW = $maxX - $minX + 1
$cropH = $maxY - $minY + 1
$cropRect = New-Object System.Drawing.Rectangle $minX, $minY, $cropW, $cropH
$croppedArtwork = $srcImg.Clone($cropRect, $srcImg.PixelFormat)
$srcImg.Dispose()

Write-Host "  📐 Tight Artwork Dimensions: ${cropW}x${cropH} (trimmed from source)" -ForegroundColor Gray

# 2. Compute proportional scaling within canvas safe zone
$scale = $TargetHeight / $cropH
$targetW = $cropW * $scale
$destX = [float](($CanvasSize - $targetW) / 2.0)
$destY = [float](($CanvasSize - $TargetHeight) / 2.0)

# Helper function to render with studio quality
function Render-Icon([string]$outputPath, [System.Drawing.Color]$bgColor) {
    $bmp = New-Object System.Drawing.Bitmap $CanvasSize, $CanvasSize
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $g.Clear($bgColor)
    $g.DrawImage($croppedArtwork, $destX, $destY, [float]$targetW, [float]$TargetHeight)
    $g.Dispose()

    $outDir = Split-Path -Parent $outputPath
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# Output targets
$targets = @(
    @{ Name = "client_assets"; Dir = "client_assets" },
    @{ Name = "Rentlyo (Tenant App)"; Dir = "Rentlyo\assets\images" },
    @{ Name = "Rentlyo Admin"; Dir = "Rentlyo Admin\assets\images" }
)

foreach ($t in $targets) {
    $iconWhite = Join-Path $t.Dir "app_icon.png"
    $iconTrans = Join-Path $t.Dir "app_icon_foreground.png"

    Render-Icon -outputPath $iconWhite -bgColor ([System.Drawing.Color]::White)
    Render-Icon -outputPath $iconTrans -bgColor ([System.Drawing.Color]::Transparent)
    Write-Host "  ✅ Generated for $($t.Name):" -ForegroundColor Green
    Write-Host "     - $iconWhite (Solid White Background)" -ForegroundColor Gray
    Write-Host "     - $iconTrans (Adaptive Transparent Foreground)" -ForegroundColor Gray
}

# Also generate Web PWA Icons for any project containing a web directory
$webDirs = @("Rentlyo\web", "Rentlyo Admin\web")
foreach ($w in $webDirs) {
    if (Test-Path $w) {
        $iconsDir = Join-Path $w "icons"
        if (-not (Test-Path $iconsDir)) { New-Item -ItemType Directory -Path $iconsDir -Force | Out-Null }
        
        # Web sizes helper
        function Render-WebIcon([string]$outPath, [int]$pixelSize) {
            $bmp = New-Object System.Drawing.Bitmap $pixelSize, $pixelSize
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $g.Clear([System.Drawing.Color]::White)

            # 55% scale for web icons safe margin
            $targetWebH = $pixelSize * 0.55
            $scaleWeb = $targetWebH / $cropH
            $targetWebW = $cropW * $scaleWeb
            $destWebX = [float](($pixelSize - $targetWebW) / 2.0)
            $destWebY = [float](($pixelSize - $targetWebH) / 2.0)

            $g.DrawImage($croppedArtwork, $destWebX, $destWebY, [float]$targetWebW, [float]$targetWebH)
            $g.Dispose()
            $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
        }

        Render-WebIcon -outPath (Join-Path $iconsDir "Icon-192.png") -pixelSize 192
        Render-WebIcon -outPath (Join-Path $iconsDir "Icon-512.png") -pixelSize 512
        Render-WebIcon -outPath (Join-Path $iconsDir "Icon-maskable-192.png") -pixelSize 192
        Render-WebIcon -outPath (Join-Path $iconsDir "Icon-maskable-512.png") -pixelSize 512
        Render-WebIcon -outPath (Join-Path $w "favicon.png") -pixelSize 64
        Write-Host "  ✅ Generated Web PWA Icons for $w (192, 512, maskable, favicon)" -ForegroundColor Green
    }
}

$croppedArtwork.Dispose()
Write-Host "🎉 App Icon Asset Generation Complete!`n" -ForegroundColor Green
