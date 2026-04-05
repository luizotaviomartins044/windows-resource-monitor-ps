# =========================================
# Monitor de Recursos Windows - v4.1
# Autor: Luiz
# Descrição: Monitoramento de CPU, Memória, Disco e Rede em tempo real
# =========================================


Clear-Host
Write-Host "Iniciando monitor..." -ForegroundColor Green
Start-Sleep 1
Clear-Host

# Função para validar as cores
function Get-ColorByUsage( $value ) {
    if ( $value -lt 75 ) { 
        return "Green" 
    } elseif ( $value -lt 90 ) { 
        return "Yellow" 
    } else { 
        return "Red" 
    }
}

$hostname = $env:COMPUTERNAME

while ($true) {
    Write-Host "==============================" -ForegroundColor "Blue"
    Write-Host "   MONITOR DE RECURSOS"         -ForegroundColor "Blue"
    Write-Host "==============================" -ForegroundColor "Blue"
    Write-Host "[CTRL + C] para sair"           -ForegroundColor DarkGray
    Write-Host (Get-Date -Format "dd/MM/yyyy HH:mm:ss") -ForegroundColor DarkGray

    
    $os = Get-CimInstance Win32_OperatingSystem

    #upTime
    $uptime = ( Get-Date ) - $os.LastBootUpTime

    # Uso da CPU
    $cpuLoad = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
    $cpu     = [int][math]::Round( $cpuLoad )
    
    # Uso da Memória
    $totalMem      = [ math ]::Round( $os.TotalVisibleMemorySize / 1MB, 2 )
    $freeMem       = [ math ]::Round( $os.FreePhysicalMemory     / 1MB, 2 )
    $usedMem       = $totalMem - $freeMem
    $memPercentage = [math]::Round(($usedMem / $totalMem) * 100, 2 )

    # Uso do Disco (C:)
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $totalDisk = [math]::Round($disk.Size / 1GB, 2 )
    $freeDisk       = [ math ]::Round( $disk.FreeSpace / 1GB, 2 )
    $usedDiskGB     = $totalDisk - $freeDisk
    if ($totalDisk -gt 0) {
        $diskPercentage = [math]::Round(($usedDiskGB / $totalDisk) * 100, 2)
    } else {
        $diskPercentage = 0
    }
    
    # Uso de Rede
    $networkAdapters = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface

    $adapter = $networkAdapters |
        Where-Object { $_.Name -notlike "*Loopback*" -and $_.BytesTotalPersec -gt 0 } |
        Sort-Object BytesTotalPersec -Descending |
        Select-Object -First 1

    if ($adapter) {
        $bytesSent     = [math]::Round($adapter.BytesSentPersec     / 1KB, 2 )
        $bytesReceived = [math]::Round($adapter.BytesReceivedPersec / 1KB, 2 )
    } else {
        $bytesSent     = 0
        $bytesReceived = 0
    }

    # Cores
    $cpuColor = Get-ColorByUsage $cpu
    $memColor = Get-ColorByUsage $memPercentage
    $disColor = Get-ColorByUsage $diskPercentage

    #Display
    Write-Host "Servidor: $hostname"                            -ForegroundColor Cyan
    Write-Host ( "Uptime: {0:dd}d {0:hh}h {0:mm}m" -f $uptime ) -ForegroundColor Cyan
    Write-Host ""

    if ($cpuLoad -gt 90) {
        Write-Host "⚠ CPU EM NÍVEL CRÍTICO!" -ForegroundColor Red
    }
    Write-Host ( "CPU:      {0,5}%" -f $cpu                                                        ) -ForegroundColor $cpuColor

    if ($memPercentage -gt 90) {
        Write-Host "⚠ MEMÓRIA CRÍTICA!" -ForegroundColor Red
    }
    Write-Host ( "Memória:  {0,5}% ( {1}GB / {2}GB ) " -f $memPercentage, $usedMem, $totalMem      ) -ForegroundColor $memColor

    if ($diskPercentage -gt 90) {
        Write-Host "⚠ DISCO CRÍTICO!" -ForegroundColor Red
    }
    Write-Host ( "Disco:    {0,5}% ( {1}GB / {2}GB ) " -f $diskPercentage, $usedDiskGB, $totalDisk ) -ForegroundColor $disColor

    Write-Host ( "Rede: ↓ {0,8} KB/s ↑ {1,8} KB/s" -f $bytesReceived, $bytesSent                   ) -ForegroundColor "Green"

    $log = "$( Get-Date ) | CPU: $cpu% | RAM: $memPercentage% | DISK: $diskPercentage%" 
    $logPath = "$PSScriptRoot\monitor.log"
    Add-Content $logPath $log

    # Intervalo entre as medições (em segundos)
    Start-Sleep -Seconds 30
	Clear-Host
}