#!/bin/bash

# Network discovery script for finding potential cluster nodes
# Usage: ./discover-nodes.sh [network_range]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default network ranges to scan
NETWORKS=(
    "192.168.1.0/24"
    "192.168.4.0/24" 
    "192.168.5.0/24"
    "10.0.0.0/24"
)

if [ $# -eq 1 ]; then
    NETWORKS=("$1")
fi

print_status "Starting network discovery..."
echo "Scanning networks: ${NETWORKS[@]}"
echo ""

# Install nmap if needed
if ! command -v nmap &> /dev/null; then
    print_status "Installing nmap..."
    sudo apt update && sudo apt install -y nmap
fi

DISCOVERED_NODES=()

for network in "${NETWORKS[@]}"; do
    print_status "Scanning network: $network"
    
    # Scan for hosts with SSH open
    nmap_output=$(nmap -p 22 --open -oG - "$network" 2>/dev/null | grep "22/open")
    
    if [ -n "$nmap_output" ]; then
        while IFS= read -r line; do
            ip=$(echo "$line" | awk '{print $2}')
            if [ "$ip" != "Host:" ]; then
                print_success "Found SSH service on: $ip"
                
                # Try to get hostname and OS info
                hostname=$(nmap -sn "$ip" 2>/dev/null | grep "Nmap scan report" | awk '{print $5}' | tr -d '()')
                if [ -z "$hostname" ] || [ "$hostname" == "$ip" ]; then
                    hostname="unknown"
                fi
                
                # Try to detect OS
                os_info=$(nmap -O "$ip" 2>/dev/null | grep "Running:" | head -1 | cut -d':' -f2 | xargs)
                if [ -z "$os_info" ]; then
                    os_info="unknown"
                fi
                
                DISCOVERED_NODES+=("$ip:$hostname:$os_info")
            fi
        done <<< "$nmap_output"
    else
        print_warning "No SSH services found on $network"
    fi
    echo ""
done

if [ ${#DISCOVERED_NODES[@]} -eq 0 ]; then
    print_error "No potential nodes discovered"
    exit 1
fi

# Display discovered nodes
print_status "Discovered ${#DISCOVERED_NODES[@]} potential nodes:"
echo ""
printf "%-15s %-20s %-30s\n" "IP Address" "Hostname" "OS Info"
printf "%-15s %-20s %-30s\n" "----------" "--------" "-------"

for node in "${DISCOVERED_NODES[@]}"; do
    IFS=':' read -r ip hostname os <<< "$node"
    printf "%-15s %-20s %-30s\n" "$ip" "$hostname" "$os"
done

echo ""

# Generate connection test script
print_status "Generating connection test script..."
cat > test-discovered-nodes.sh << 'EOF'
#!/bin/bash
# Test connections to discovered nodes
# Usage: ./test-discovered-nodes.sh

NODES=(
EOF

for node in "${DISCOVERED_NODES[@]}"; do
    IFS=':' read -r ip hostname os <<< "$node"
    echo "    \"$ip:$hostname\"" >> test-discovered-nodes.sh
done

cat >> test-discovered-nodes.sh << 'EOF'
)

echo "Testing connections to discovered nodes..."
echo ""

for node in "${NODES[@]}"; do
    IFS=':' read -r ip hostname <<< "$node"
    echo "Testing $ip ($hostname)..."
    
    # Test ping
    if ping -c 1 -W 2 "$ip" > /dev/null 2>&1; then
        echo "  ✓ Ping: OK"
    else
        echo "  ✗ Ping: Failed"
        continue
    fi
    
    # Test SSH port
    if nc -z -w 2 "$ip" 22 2>/dev/null; then
        echo "  ✓ SSH Port: Open"
    else
        echo "  ✗ SSH Port: Closed"
        continue
    fi
    
    # Try to get SSH banner
    ssh_banner=$(timeout 5 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$ip" exit 2>&1 | head -1)
    if [[ "$ssh_banner" == *"Permission denied"* ]] || [[ "$ssh_banner" == *"password"* ]]; then
        echo "  ✓ SSH Service: Responding"
    else
        echo "  ? SSH Service: $ssh_banner"
    fi
    
    echo ""
done

echo "Connection testing completed."
echo "Use credentials to test actual SSH access:"
echo "  ssh username@ip_address"
EOF

chmod +x test-discovered-nodes.sh

print_success "Discovery completed!"
print_status "Next steps:"
echo "1. Run: ./test-discovered-nodes.sh"
echo "2. Test SSH access with known credentials"
echo "3. Use: ./scripts/test-node-setup.sh <ip> <username> <password>"
echo ""
