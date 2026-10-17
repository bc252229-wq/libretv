$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$nodeDir = 'C:\Users\31598\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin'
$env:PATH = "$nodeDir;$env:PATH"
$cf  = 'C:\Users\31598\.cloudflared\cloudflared.exe'
$log = 'C:\Users\31598\.cloudflared\tunnel.log'

Write-Host '=== LibreTV 公网镜像 ==='

# 1) 本地服务
if (-not (Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)) {
  Write-Host '[1/3] 启动本地服务 ...'
  Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$root\node_modules\.bin\next.CMD`" start -p 8080" -WorkingDirectory $root -WindowStyle Hidden
  for ($i=0; $i -lt 45; $i++) { Start-Sleep -Seconds 1; if (Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue) { break } }
} else { Write-Host '[1/3] 本地服务已在运行' }

# 2) 弹幕聚合服务
if (-not (Get-NetTCPConnection -LocalPort 9321 -State Listen -ErrorAction SilentlyContinue)) {
  $danmuDir = 'C:\Users\31598\.danmu-api'
  if (Test-Path "$danmuDir\danmu_api\server.js") {
    Write-Host '[2/3] 启动弹幕聚合服务 ...'
    Start-Process -FilePath "$nodeDir\node.exe" -ArgumentList 'danmu_api/server.js' -WorkingDirectory $danmuDir -WindowStyle Hidden
    for ($i=0; $i -lt 45; $i++) { Start-Sleep -Seconds 1; if (Get-NetTCPConnection -LocalPort 9321 -State Listen -ErrorAction SilentlyContinue) { break } }
  } else { Write-Host '[2/3] 未找到弹幕服务目录，跳过' }
} else { Write-Host '[2/3] 弹幕聚合服务已在运行' }

# 3) 公网隧道
$tunnelUp = $false
foreach ($p in (Get-CimInstance Win32_Process -Filter "Name='cloudflared.exe'" -ErrorAction SilentlyContinue)) {
  if ($p.CommandLine -and $p.CommandLine -like '*localhost:8080*') { $tunnelUp = $true }
}
if (-not $tunnelUp) {
  Write-Host '[3/3] 启动公网隧道 ...'
  Remove-Item $log -ErrorAction SilentlyContinue
  Start-Process -FilePath $cf -ArgumentList @('tunnel','--url','http://localhost:8080','--no-autoupdate','--logfile',"`"$log`"") -WindowStyle Hidden
} else { Write-Host '[3/3] 公网隧道已在运行' }

# 4) 读地址
$url = $null
for ($i=0; $i -lt 45; $i++) {
  Start-Sleep -Seconds 1
  if (Test-Path $log) {
    $m = [regex]::Match((Get-Content $log -Raw), 'https://[a-z0-9-]+\.trycloudflare\.com')
    if ($m.Success) { $url = $m.Value; break }
  }
}
Write-Host ''
if ($url) {
  Write-Host '公网地址: ' -NoNewline; Write-Host $url -ForegroundColor Green
  try { Set-Clipboard -Value $url; Write-Host '（地址已复制到剪贴板）' } catch {}
  Write-Host '本机使用: http://localhost:8080'
} else {
  Write-Host '未能获取公网地址，请查看: ' $log -ForegroundColor Yellow
}