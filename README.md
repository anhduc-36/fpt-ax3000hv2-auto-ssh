# AX3000HV2 Auto SSH

## Prerequisites

### Windows:
- **PowerShell Version:** Requires PowerShell 3.0 or higher.
- **Network Profile:** Ensure your network connection is set to **Private** instead of Public.

### Linux:
- Ensure you have `bash` installed.
- Root or sudo privileges are required for script execution.

---

## Instructions

### 1. Execution

#### On Windows (PowerShell):
1. Open PowerShell as Administrator.
2. Navigate to the script directory.
3. Run the following command:
   .\\attack_script.ps1

#### On Linux (Bash):
1. Open your terminal.
2. Navigate to the script directory.
3. Give the script execution permissions:
   chmod +x attack_script.sh
4. Run the script with sudo:
   sudo ./attack_script.sh

### 2. Accessing the Device via SSH

After the script has successfully finished running, you can connect to the device using SSH.

**Command:**
ssh admin@your_ax3000hv2_ip

**Password Information:**
- Your initial login password is the same as your **192.168.1.1** web interface password.
