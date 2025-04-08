# Require Admin Privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoExit -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

# Function: Get Processes with Ports
function Get-ProcessWithPorts {
    $tcpConnections = Get-NetTCPConnection -State Listen, Established -ErrorAction SilentlyContinue

    Get-Process | ForEach-Object {
        $process = $_
        $ports = $tcpConnections | 
                 Where-Object { $_.OwningProcess -eq $process.Id } | 
                 Select-Object -ExpandProperty LocalPort -Unique |
                 ForEach-Object { $_.ToString().Trim() }

        [PSCustomObject]@{
            PID         = $process.Id
            ProcessName = $process.ProcessName
            TCPPorts    = if ($ports) { $ports -join ', ' } else { 'N/A' }
        }
    }
}

# 修复函数：通过端口搜索进程（严格匹配）
function Search-ProcessByPort($port) {
    Get-ProcessWithPorts | Where-Object { 
        $_.TCPPorts -split ',\s*' -contains $port.ToString()
    } | Format-Table -AutoSize @(
        @{Label="PID"; Expression={$_.PID}; Alignment="Center"},
        @{Label="ProcessName"; Expression={$_.ProcessName}; Alignment="Center"},
        @{Label="TCPPorts"; Expression={$_.TCPPorts}; Alignment="Center"}
    )
}

# 主逻辑循环
$refreshNeeded = $true
do {
    # 刷新列表逻辑
    if ($refreshNeeded) {
        Clear-Host
        Write-Host "`nProcess List with TCP Ports:`n"
        Get-ProcessWithPorts | Format-Table -AutoSize @(
            @{Label="PID"; Expression={$_.PID}; Alignment="Center"},
            @{Label="ProcessName"; Expression={$_.ProcessName}; Alignment="Center"},
            @{Label="TCPPorts"; Expression={$_.TCPPorts}; Alignment="Center"}
        )
        $refreshNeeded = $false
    }

    # 显示命令提示（不自动清屏）
    Write-Host "`nCommands:"
    Write-Host "  kill [PID]      - Terminate process by PID"
    Write-Host "  search [PORT]   - Find processes using specific port"
    Write-Host "  clean [PORT]    - Kill all processes using specific port"
    Write-Host "  refresh         - Reload list"
    Write-Host "  exit            - Quit program`n"

    # 读取用户输入（无阻塞等待）
    $input = Read-Host -Prompt "Enter command"
    $command = $input -split ' '

    # 处理命令
    switch ($command[0].ToLower()) {
        'kill' {
            if ($command.Count -ge 2) {
                $pidToKill = $command[1]
                try {
                    Stop-Process -Id $pidToKill -Force -ErrorAction Stop
                    Write-Host "`n[SUCCESS] Process $pidToKill terminated." -ForegroundColor Green
                } catch {
                    Write-Host "`n[ERROR] Failed to terminate process $pidToKill" -ForegroundColor Red
                }
            }
        }
        'search' {
            if ($command.Count -ge 2 -and $command[1] -match '^\d+$') {
                $targetPort = $command[1]
                Write-Host "`nProcesses using port $targetPort :`n"
                $result = Search-ProcessByPort $targetPort
                if (-not $result) {
                    Write-Host "No processes found using port $targetPort" -ForegroundColor Yellow
                }
            } else {
                Write-Host "`n[ERROR] Invalid port number. Usage: search [PORT]" -ForegroundColor Red
            }
        }
        'clean' {
            if ($command.Count -ge 2 -and $command[1] -match '^\d+$') {
                $targetPort = $command[1]
                $processesToKill = Get-ProcessWithPorts | Where-Object { 
                    $_.TCPPorts -split ',\s*' -contains $targetPort.ToString() 
                }
                
                if ($processesToKill) {
                    $processesToKill | ForEach-Object {
                        try {
                            Stop-Process -Id $_.PID -Force -ErrorAction Stop
                            Write-Host "[SUCCESS] Killed PID $($_.PID) ($($_.ProcessName))" -ForegroundColor Green
                        } catch {
                            Write-Host "[ERROR] Failed to kill PID $($_.PID)" -ForegroundColor Red
                        }
                    }
                } else {
                    Write-Host "No processes using port $targetPort" -ForegroundColor Yellow
                }
            } else {
                Write-Host "`n[ERROR] Invalid port number. Usage: clean [PORT]" -ForegroundColor Red
            }
        }
        'refresh' { 
            $refreshNeeded = $true
        }
        'exit' { return }
        default {
            Write-Host "`n[ERROR] Invalid command. Valid commands: kill, search, clean, refresh, exit" -ForegroundColor Yellow
        }
    }

    # 添加空行分隔命令结果
    Write-Host ""

} while ($true)