# Raspberry Pi Cluster Integration Guide

## Current Cluster Status
✅ **Master Node**: steve-ideapad-flex-5-15alc05 (192.168.4.157)
✅ **Worker Node**: steve-thinkpad-l490 (192.168.5.57)
❌ **Missing**: Raspberry Pi (previously at 192.168.4.186)

## Step-by-Step Pi Recovery

### 1. Physical Check
- [ ] Ensure Raspberry Pi is powered on (check power LED)
- [ ] Verify network connection (ethernet cable or WiFi)
- [ ] Check if Pi has HDMI connected for direct access if needed

### 2. Find the Pi's Current IP
**Option A: Check your router's DHCP client list**
- Log into your router admin interface
- Look for devices named "raspberry" or with MAC starting with: b8:27:eb, dc:a6:32, or e4:5f:01

**Option B: Use network scanning**
```bash
# Run the discovery script we created
./find-raspberry-pi.sh

# Or manual scan
nmap -sn 192.168.1.0/24  # Try different subnets as needed
nmap -sn 192.168.4.0/24
```

**Option C: Direct connection**
- Connect Pi directly to your computer with ethernet
- Or connect monitor/keyboard to Pi and check `ip addr show`

### 3. Once Pi is Found
**Update the inventory with the correct IP:**
```bash
# If Pi is at a different IP (e.g., 192.168.4.200)
sed -i 's/192.168.4.186/192.168.4.200/g' ansible/inventory.ini
```

**Test connectivity:**
```bash
./add-pi-to-cluster.sh [PI_IP] [USERNAME]
# Example: ./add-pi-to-cluster.sh 192.168.4.200 pi
```

### 4. Add Pi to Cluster
**Setup the Pi as a worker node:**
```bash
ansible-playbook -i ansible/inventory.ini ansible/setup-rpi-worker.yml
```

**Join the cluster (run on the Pi):**
```bash
# SSH to the Pi and run this join command:
sudo kubeadm join 192.168.4.157:6443 --token kj8ug9.7a7bqx1ohshrbmp3 --discovery-token-ca-cert-hash sha256:b07498d5977e3d91474bf2c717780f8491a242d3aa8f26a80bfda85a296d4a8b
```

### 5. Verify Pi in Cluster
```bash
ansible master -i ansible/inventory_working.ini -m shell -a "export KUBECONFIG=/etc/kubernetes/admin.conf && kubectl get nodes -o wide" --become
```

## Troubleshooting

### Pi Not Found on Network
1. **Power cycle the Pi** - Unplug for 10 seconds, plug back in
2. **Check network cables** - Ensure ethernet is properly connected
3. **Try different subnet** - Pi might be on 192.168.1.x instead of 192.168.4.x
4. **Connect directly** - Use HDMI + keyboard to access Pi console

### SSH Issues
1. **Enable SSH** (if connecting directly to Pi):
   ```bash
   sudo systemctl enable ssh
   sudo systemctl start ssh
   ```
2. **Check SSH keys** - You might need to use password auth initially
3. **Username** - Default is usually `pi` but might be `ubuntu` depending on OS

### Cluster Join Issues
1. **Firewall** - Ensure ports 6443, 10250, 10256 are open
2. **Time sync** - Ensure Pi time is synchronized
3. **New token** - If token expires, generate new one:
   ```bash
   ansible master -i ansible/inventory_working.ini -m shell -a "export KUBECONFIG=/etc/kubernetes/admin.conf && kubeadm token create --print-join-command" --become
   ```

## Expected Final Result
Once successful, you should see:
```
NAME                           STATUS   ROLES           AGE   VERSION
steve-ideapad-flex-5-15alc05   Ready    control-plane   39h   v1.28.15
steve-thinkpad-l490            Ready    <none>          37h   v1.28.15
rpi-control                    Ready    <none>          1m    v1.28.15
```
