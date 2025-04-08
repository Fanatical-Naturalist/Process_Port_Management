# Require Admin Privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoExit -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

# Function: Get Processes with Ports (修复端口数据获取)
function Get-ProcessWithPorts {
    # 获取所有 TCP 连接（包括 Listen 和 Established 状态）
    $tcpConnections = Get-NetTCPConnection -State Listen, Established -ErrorAction SilentlyContinue

    # 合并进程和端口信息（修复端口匹配逻辑）
    Get-Process | ForEach-Object {
        $process = $_
        # 精确匹配进程 PID 和 TCP 连接的 OwningProcess
        $ports = $tcpConnections | 
                 Where-Object { $_.OwningProcess -eq $process.Id } | 
                 Select-Object -ExpandProperty LocalPort -Unique |
                 ForEach-Object { $_.ToString().Trim() }  # 确保端口为字符串且无空格

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
        # 分割端口字符串并精确匹配
        $_.TCPPorts -split ',\s*' -contains $port.ToString()
    } | Format-Table -AutoSize @(
        @{Label="PID"; Expression={$_.PID}; Alignment="Center"},
        @{Label="ProcessName"; Expression={$_.ProcessName}; Alignment="Center"},
        @{Label="TCPPorts"; Expression={$_.TCPPorts}; Alignment="Center"}
    )
}

# 主逻辑循环
do {
    Clear-Host

    # 输出进程列表（优化对齐）
    Write-Host "`nProcess List with TCP Ports:`n"
    Get-ProcessWithPorts | Format-Table -AutoSize @(
        @{Label="PID"; Expression={$_.PID}; Alignment="Center"},
        @{Label="ProcessName"; Expression={$_.ProcessName}; Alignment="Center"},
        @{Label="TCPPorts"; Expression={$_.TCPPorts}; Alignment="Center"}
    )

    Write-Host "`nCommands:"
    Write-Host "  kill [PID]      - Terminate process by PID"
    Write-Host "  search [PORT]   - Find processes using specific port"
    Write-Host "  clean [PORT]    - Kill all processes using specific port"
    Write-Host "  refresh         - Reload list"
    Write-Host "  exit            - Quit program`n"

    $input = Read-Host -Prompt "Enter command"
    $command = $input -split ' '

    switch ($command[0].ToLower()) {
        'kill' {
            if ($command.Count -ge 2) {
                $pidToKill = $command[1]
                try {
                    Stop-Process -Id $pidToKill -Force -ErrorAction Stop
                    Write-Host "`nProcess $pidToKill terminated. Press Enter to refresh..." -ForegroundColor Green
                    Read-Host
                } catch {
                    Write-Host "`nError: Failed to terminate process $pidToKill" -ForegroundColor Red
                    Read-Host "Press Enter to continue..."
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
                Read-Host "`nPress Enter to continue..."
            } else {
                Write-Host "`nInvalid port number. Usage: search [PORT]" -ForegroundColor Red
                Read-Host "Press Enter to continue..."
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
                            Write-Host "Killed PID $($_.PID) ($($_.ProcessName))" -ForegroundColor Green
                        } catch {
                            Write-Host "Failed to kill PID $($_.PID)" -ForegroundColor Red
                        }
                    }
                } else {
                    Write-Host "No processes using port $targetPort" -ForegroundColor Yellow
                }
                Read-Host "`nPress Enter to refresh..."
            } else {
                Write-Host "`nInvalid port number. Usage: clean [PORT]" -ForegroundColor Red
                Read-Host "Press Enter to continue..."
            }
        }
        'refresh' { continue }
        'exit' { return }
        default {
            Write-Host "`nInvalid command. Valid commands: kill, search, clean, refresh, exit" -ForegroundColor Yellow
            Read-Host "Press Enter to continue..."
        }
    }
} while ($true)
