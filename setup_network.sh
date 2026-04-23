#!/bin/bash
# GNSS Recorder Network Setup Utility
# Resets IP routing and stops interfering services

echo "=========================================="
echo " 🌐 Hardening Network and Sensor State "
echo "=========================================="

# 1. Clean up ANY dead or hanging LiDAR/GNSS processes
sudo pkill -f ouster 2>/dev/null || true
sudo pkill -x gpsd 2>/dev/null || true
sudo systemctl stop gpsd.socket gpsd.service 2>/dev/null || true

# 2. Reset the Network Routes (Forces LiDAR traffic to the native port)
# Adjust 'enp3s0' if the interface name is different on the new machine
INTERFACE="enp3s0"
LIDAR_IP="169.254.51.134"

echo "[1/2] Resetting routes for $LIDAR_IP via $INTERFACE..."
sudo ip route del $LIDAR_IP 2>/dev/null || true
sudo ip route add $LIDAR_IP dev $INTERFACE
sleep 2

# 3. Verify LiDAR Connectivity
echo "[2/2] Verifying connectivity..."
if ping -c 1 -W 2 $LIDAR_IP > /dev/null; then
    echo "✅ SUCCESS: LiDAR is reachable."
else
    echo "❌ ERROR: LiDAR ($LIDAR_IP) IS NOT REACHABLE!"
    echo "   Check: Hardware link (LEDs), Ethernet cable, and interface name ($INTERFACE)."
    exit 1
fi

echo "=========================================="
echo " ✅ Network is ready for recording!"
echo "=========================================="
