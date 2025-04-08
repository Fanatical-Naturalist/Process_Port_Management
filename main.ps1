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

# 过滤非N/A端口的进程
function Get-FilteredProcesses($showAll) {
    $rawData = Get-ProcessWithPorts
    if (-not $showAll) {
        $rawData | Where-Object { $_.TCPPorts -ne 'N/A' }
    } else {
        $rawData
    }
}

# 主逻辑循环
$refreshNeeded = $true
$showAllProcesses = $false
do {
    # 刷新列表逻辑
    if ($refreshNeeded) {
        Clear-Host
        $currentProcessList = Get-FilteredProcesses -showAll $showAllProcesses
        Write-Host "`nProcess List with TCP Ports ($(if ($showAllProcesses) {'All'} else {'Filtered'})):`n"
        $currentProcessList | Format-Table -AutoSize @(
            @{Label="PID"; Expression={$_.PID}; Alignment="Center"},
            @{Label="ProcessName"; Expression={$_.ProcessName}; Alignment="Center"},
            @{Label="TCPPorts"; Expression={$_.TCPPorts}; Alignment="Center"}
        )
        $refreshNeeded = $false
    }

    # 显示命令提示（已移除 search 命令）
    Write-Host "`nCommands:"
    Write-Host "  kill [PID]      - Terminate process by PID"
    Write-Host "  clean [PORT]    - Kill all processes using specific port"
    Write-Host "  filter          - Toggle port filter (current: $(if ($showAllProcesses) {'Show All'} else {'Hide N/A'}))"
    Write-Host "  refresh         - Reload filtered list"
    Write-Host "  refresh all     - Reload full list"
    Write-Host "  exit            - Quit program`n"

    # 读取用户输入（直接响应 exit 命令）
    $input = Read-Host -Prompt "Enter command"
    $command = $input -split ' '

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
        'clean' {
            if ($command.Count -ge 2 -and $command[1] -match '^\d+$') {
                $targetPort = $command[1]
                $processesToKill = $currentProcessList | Where-Object { 
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
        'filter' {
            $showAllProcesses = -not $showAllProcesses
            $refreshNeeded = $true
        }
        'refresh' {
            if ($command.Count -ge 2 -and $command[1] -eq 'all') {
                $showAllProcesses = $true
            } else {
                $showAllProcesses = $false
            }
            $refreshNeeded = $true
        }
        'exit' { 
            exit  # 直接退出脚本，无需额外操作
        }
        default {
            Write-Host "`n[ERROR] Invalid command. Valid commands: kill, clean, filter, refresh, exit" -ForegroundColor Yellow
        }
    }

    Write-Host ""
} while ($true)