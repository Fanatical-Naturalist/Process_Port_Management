# 要求管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoExit -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

# 函数：获取进程及其 TCP 端口（兼容多语言环境）
function Get-ProcessWithPorts {
    # 获取所有 TCP 连接（需管理员权限）
    $tcpConnections = Get-NetTCPConnection -State Listen, Established -ErrorAction SilentlyContinue

    # 合并进程和端口信息
    Get-Process | ForEach-Object {
        $process = $_
        $ports = $tcpConnections | 
                 Where-Object { $_.OwningProcess -eq $process.Id } | 
                 Select-Object -ExpandProperty LocalPort -Unique |
                 ForEach-Object { $_.ToString() }  # 确保端口转为字符串

        [PSCustomObject]@{
            PID         = $process.Id
            ProcessName = $process.ProcessName
            TCPPorts    = if ($ports) { $ports -join ', ' } else { 'N/A' }
        }
    }
}

# 主逻辑循环
do {
    # 清空屏幕
    Clear-Host

    # 输出进程及端口信息
    Write-Host "`n进程列表（含 TCP 端口）:`n"
    Get-ProcessWithPorts | Format-Table -AutoSize -Property PID, ProcessName, TCPPorts

    # 用户操作提示
    Write-Host "`n可用命令："
    Write-Host "  kill [PID]  - 终止指定 PID 的进程（例如 kill 1234）"
    Write-Host "  refresh     - 刷新进程列表"
    Write-Host "  exit        - 退出程序`n"

    # 读取用户输入
    $input = Read-Host -Prompt "请输入命令"
    $command = $input -split ' '

    # 处理命令
    switch ($command[0].ToLower()) {
        'kill' {
            if ($command.Count -ge 2) {
                $pidToKill = $command[1]
                try {
                    Stop-Process -Id $pidToKill -Force -ErrorAction Stop
                    Write-Host "`n进程 $pidToKill 已终止。按回车刷新列表..."
                    Read-Host
                } catch {
                    Write-Host "`n错误：无法终止进程 $pidToKill（权限不足或 PID 无效）" -ForegroundColor Red
                    Read-Host "按回车继续..."
                }
            } else {
                Write-Host "`n错误：请输入完整的 kill 命令（例如 kill 1234）" -ForegroundColor Red
                Read-Host "按回车继续..."
            }
        }
        'refresh' { 
            # 直接继续循环以刷新列表
            continue
        }
        'exit' { 
            return  # 退出程序
        }
        default {
            Write-Host "`n错误：未知命令，请输入 'kill [PID]'、'refresh' 或 'exit'" -ForegroundColor Yellow
            Read-Host "按回车继续..."
        }
    }
} while ($true)