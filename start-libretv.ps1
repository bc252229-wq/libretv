$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$nodeDir = 'C:\Users\31598\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin'
$env:PATH = "$nodeDir;$env:PATH"

function Wait-Port([int]$Port, [int]$Seconds) {
  for ($i = 0; $i -lt $Seconds; $i++) {
    if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { return $true }
    Start-Sleep -Seconds 1
  }
  return $false
}

Write-Host '=== LibreTV 启动器 ==='

# 1) 主站
if (-not (Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)) {
  Write-Host '[1/2] 启动 LibreTV 主站 ...'
  Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$root\node_modules\.bin\next.CMD`" start -p 8080" -WorkingDirectory $root -WindowStyle Hidden
  [void](Wait-Port 8080 45)
} else { Write-Host '[1/2] LibreTV 主站已在运行' }

# 2) 弹幕聚合服务
if (-not (Get-NetTCPConnection -LocalPort 9321 -State Listen -ErrorAction SilentlyContinue)) {
  $danmuDir = 'C:\Users\31598\.danmu-api'
  if (Test-Path "$danmuDir\danmu_api\server.js") {
    Write-Host '[2/2] 启动弹幕聚合服务 ...'
    Start-Process -FilePath "$nodeDir\node.exe" -ArgumentList 'danmu_api/server.js' -WorkingDirectory $danmuDir -WindowStyle Hidden
    [void](Wait-Port 9321 45)
  } else {
    Write-Host '[2/2] 未找到弹幕服务目录，跳过'
  }
} else { Write-Host '[2/2] 弹幕聚合服务已在运行' }

# 3) 打开浏览器
Start-Process 'http://localhost:8080'