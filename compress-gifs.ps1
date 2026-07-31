$ffmpeg = "C:\Users\user\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.2-full_build\bin\ffmpeg.exe"
$gifDir = "public\assets\REVAMPED\revamp website_\home page\assets\png file-w\zylo\GIFs"

$gifs = @(
  @{ In = "boxing.gif";          Out = "boxing-anim.webp" },
  @{ In = "DEADLIFT.gif";        Out = "deadlift-anim.webp" },
  @{ In = "jogging.gif";         Out = "jogging-anim.webp" },
  @{ In = "meditation.gif";      Out = "meditation-anim.webp" },
  @{ In = "pilates.gif";         Out = "pilates-anim.webp" },
  @{ In = "RESTING.gif";         Out = "resting-anim.webp" },
  @{ In = "stretching.gif";      Out = "stretching-anim.webp" },
  @{ In = "Worlds Greatest.gif"; Out = "worlds-greatest-anim.webp" }
)

foreach ($item in $gifs) {
  $inputPath  = Join-Path $gifDir $item.In
  $outputPath = Join-Path $gifDir $item.Out

  if (Test-Path $outputPath) {
    $existingMB = [math]::Round((Get-Item $outputPath).Length/1MB, 2)
    Write-Host "SKIP (exists): $($item.Out) = ${existingMB}MB"
    continue
  }

  $sizeMB = [math]::Round((Get-Item $inputPath).Length/1MB, 1)
  Write-Host "Converting $($item.In) (${sizeMB}MB) -> $($item.Out) ..."

  & $ffmpeg -y -i $inputPath `
    -vf "fps=12,scale=560:-1:flags=lanczos" `
    -c:v libwebp_anim `
    -quality 65 `
    -loop 0 `
    -an `
    $outputPath

  if (Test-Path $outputPath) {
    $outMB = [math]::Round((Get-Item $outputPath).Length/1MB, 2)
    Write-Host "Done: $($item.Out) = ${outMB}MB"
  } else {
    Write-Host "ERROR: $($item.Out) was not created"
  }
}

Write-Host ""
Write-Host "=== Final sizes ==="
Get-ChildItem $gifDir -Filter "*-anim.webp" | Select-Object Name, @{Name="SizeMB";Expression={[math]::Round($_.Length/1MB,2)}}
