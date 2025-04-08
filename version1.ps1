# Require Admin Privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoExit -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

# Function: Get Processes with Ports (Language-Agnostic)
function Get-ProcessWithPorts {
    # Use WMI to get TCP connections (property names are always in English)
    $connections = Get-CimInstance -ClassName Win32_PerfFormattedData_Tcpip_TCPv4 | 
                   Where-Object { $_.State -eq 5 -or $_.State -eq 1 }  # 5=Established, 1=Listen

    # Merge process and port data
    Get-Process | ForEach-Object {
        $process = $_
        $ports = $connections | 
                 Where-Object { $_.IDProcess -eq $process.Id } | 
                 Select-Object -ExpandProperty LocalPort -Unique
        [PSCustomObject]@{
            PID = $process.Id
            ProcessName = $process.ProcessName
            Ports = if ($ports) { $ports -join ', ' } else { 'N/A' }
        }
    }
}

# Main Logic
do {
    Clear-Host
    Write-Host "`nProcess List with Ports:`n"
    Get-ProcessWithPorts | Format-Table -AutoSize

    Write-Host "`nCommands:"
    Write-Host "  kill [PID]  - Terminate a process by PID (e.g., kill 1234)"
    Write-Host "  refresh     - Reload the process list"
    Write-Host "  exit        - Quit the program`n"

    $input = Read-Host -Prompt "Enter command"
    $command = $input -split ' '

    switch ($command[0].ToLower()) {
        'kill' {
            if ($command.Count -ge 2) {
                $pidToKill = $command[1]
                try {
                    Stop-Process -Id $pidToKill -Force -ErrorAction Stop
                    Write-Host "`nProcess $pidToKill terminated. Press Enter to refresh..."
                    Read-Host
                } catch {
                    Write-Host "`nError: Failed to terminate process $pidToKill (Permission denied or invalid PID)" -ForegroundColor Red
                    Read-Host "Press Enter to continue..."
                }
            }
        }
        'refresh' { continue }  # Loop will reload the list
        'exit' { return }
        default {
            Write-Host "`nInvalid command. Use 'kill [PID]', 'refresh', or 'exit'" -ForegroundColor Yellow
            Read-Host "Press Enter to continue..."
        }
    }
} while ($true)