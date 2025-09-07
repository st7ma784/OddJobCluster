#!/bin/bash

echo "🔍 Scanning for Raspberry Pi devices on network..."
echo "=========================================="

# Scan multiple subnets that might contain the Pi
SUBNETS=("192.168.4.0/24" "192.168.1.0/24" "192.168.0.0/24" "192.168.5.0/24")

for subnet in "${SUBNETS[@]}"; do
    echo "Scanning subnet: $subnet"
    
    # Look for devices with Raspberry Pi MAC address prefixes
    nmap -sn "$subnet" 2>/dev/null | while read line; do
        if [[ $line =~ "Nmap scan report for" ]]; then
            ip=$(echo $line | awk '{print $NF}' | tr -d '()')
            echo "Checking device: $ip"
            
            # Try to get MAC address
            mac=$(arp -n "$ip" 2>/dev/null | awk '{print $3}')
            
            # Raspberry Pi MAC prefixes
            if [[ $mac =~ ^(b8:27:eb|dc:a6:32|e4:5f:01) ]]; then
                echo "🎯 FOUND Raspberry Pi at: $ip (MAC: $mac)"
            fi
            
            # Also try SSH to see if it responds on port 22
            timeout 2 nc -z "$ip" 22 2>/dev/null && echo "  ✅ SSH port 22 open on $ip"
        fi
    done
done

echo ""
echo "🔧 If Pi not found, try:"
echo "1. Check Pi power and network connection"
echo "2. Connect Pi directly to router with ethernet"
echo "3. Check router's DHCP client list"
echo "4. Try connecting monitor/keyboard to Pi directly"
