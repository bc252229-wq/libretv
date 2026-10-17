$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$nodeDir = 'C:\Users\31598\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin'
$env:PATH = "$nodeDir;$env:PATH"

function Wait-Port([int]$Port, [int]$Seconds) {
  for ($i = 0; $i -lt $Seconds; $i++) {
    if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { return $true }
    Start-Sleep -Seconds 1
  }
  return $false
}

Write-Host '=== LibreTV 国内链接（localhost.run，免注册）==='

# 1) 主站
if (-not (Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)) {
  Write-Host '[1/3] 启动 LibreTV ...'
  Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$root\node_modules\.bin\next.CMD`" start -p 8080" -WorkingDirectory $root -WindowStyle Hidden
  [void](Wait-Port 8080 45)
} else { Write-Host '[1/3] LibreTV 已在运行' }

# 2) 弹幕服务
if (-not (Get-NetTCPConnection -LocalPort 9321 -State Listen -ErrorAction SilentlyContinue)) {
  $danmuDir = 'C:\Users\31598\.danmu-api'
  if (Test-Path "$danmuDir\danmu_api\server.js") {
    Write-Host '[2/3] 启动弹幕服务 ...'
    Start-Process -FilePath "$nodeDir\node.exe" -ArgumentList 'danmu_api/server.js' -WorkingDirectory $danmuDir -WindowStyle Hidden
    [void](Wait-Port 9321 45)
  } else { Write-Host '[2/3] 未找到弹幕服务目录，跳过' }
} else { Write-Host '[2/3] 弹幕服务已在运行' }

# 3) 隧道
Write-Host '[3/3] 建立国内隧道 ...'
foreach ($p in (Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" -ErrorAction SilentlyContinue)) {
  if ($p.CommandLine -and $p.CommandLine -like '*localhost.run*') { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
}
$out = Join-Path $env:TEMP 'lhr-tunnel.out'
$err = Join-Path $env:TEMP 'lhr-tunnel.err'
Remove-Item $out,$err -ErrorAction SilentlyContinue
Start-Process -FilePath 'ssh.exe' -ArgumentList @('-o','StrictHostKeyChecking=no','-o','ServerAliveInterval=30','-R','80:127.0.0.1:8080','nokey@localhost.run') -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err

$url = $null
for ($i = 0; $i -lt 50; $i++) {
  Start-Sleep -Seconds 1
  if (Test-Path $out) {
    $raw = Get-Content $out -Raw -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      $m = [regex]::Match($raw, 'https://[a-z0-9]+\.lhr\.life')
      if ($m.Success) { $url = $m.Value; break }
    }
  }
}
Write-Host ''
if ($url) {
  Write-Host '国内链接: ' -NoNewline
  Write-Host $url -ForegroundColor Green
  try { Set-Clipboard -Value $url; Write-Host '（已复制到剪贴板）' } catch {}
  Write-Host '说明：电脑需保持开机；重开隧道地址会变。'
} else {
  Write-Host '未能获取链接，请检查网络后重试。' -ForegroundColor Yellow
}