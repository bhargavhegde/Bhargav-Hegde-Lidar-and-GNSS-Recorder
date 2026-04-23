#!/bin/bash
# GNSS Recorder - One-Click Synchronized Recording
# Automatically starts all drivers and captures a rosbag.

# Configuration (Relative to script location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/ouster_params.yaml"
BRIDGE_SCRIPT="$SCRIPT_DIR/scripts/sbp_ros2_bridge.py"
DATA_DIR="$SCRIPT_DIR/data"

source /opt/ros/humble/setup.bash

echo "=========================================="
echo " 🔴 Starting Synchronized Recording Suite "
echo "=========================================="

# 1. Clean up background interference
sudo pkill -x gpsd 2>/dev/null || true
sudo systemctl stop gpsd.socket gpsd.service 2>/dev/null || true

# 2. Start Ouster LiDAR (PTP Mode)
echo "[1/4] Starting Ouster LiDAR..."
ros2 launch ouster_ros driver.launch.py params_file:="$CONFIG_FILE" &
OUSTER_PID=$!

# 3. Start GNSS Bridge (Swift SBP Binary)
echo "[2/4] Starting GNSS SBP Bridge..."
/usr/bin/python3.10 "$BRIDGE_SCRIPT" &
GNSS_PID=$!

# 4. Calibration (1.0m Forward)
echo "[3/4] Publishing Static Calibration..."
ros2 run tf2_ros static_transform_publisher 1.0 0.0 0.0 0.0 0.0 0.0 gnss_link ouster_sensor &
TF_PID=$!

echo "Waiting 8 seconds for drivers to warm up..."
sleep 8

# 5. Bag Recording
TIMESTAMP=$(date +"%Y_%m_%d_%H_%M_%S")
BAG_NAME="recording_$TIMESTAMP"
mkdir -p "$DATA_DIR"

function cleanup {
    echo ""
    echo "=========================================="
    echo " ✋ Stopping recording and saving data... "
    echo "=========================================="
    kill -INT $OUSTER_PID $GNSS_PID $TF_PID 2>/dev/null || true
    wait $OUSTER_PID $GNSS_PID $TF_PID 2>/dev/null || true
    echo "✅ Success! Bag saved in $DATA_DIR/$BAG_NAME"
    exit 0
}
trap cleanup INT TERM

echo "[4/4] 🔴 RECORDING UNLIMITED DATA..."
echo "      Saving to: $BAG_NAME"
echo "      Press [Ctrl+C] to stop."
echo "=========================================="

cd "$DATA_DIR"
ros2 bag record -o "$BAG_NAME" \
    /ouster/points \
    /ouster/imu \
    /fix \
    /tf_static
