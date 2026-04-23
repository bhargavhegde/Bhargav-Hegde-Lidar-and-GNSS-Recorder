# GNSS & LiDAR Recording Suite

A portable, one-click solution for recording PTP-synchronized datasets from an Ouster OS1 LiDAR and a Swift Navigation GNSS receiver.

---

## 🛠️ Hardware Setup
1. **Antenna:** Place the GNSS antenna with a clear view of the sky.
2. **LiDAR:** Mount the Ouster LiDAR securely.
3. **Connections:** 
   - GNSS USB-C Adapter -> Laptop USB-C.
   - LiDAR Ethernet -> Laptop Native Ethernet Port (`enp3s0`).

---

## 💻 Software Setup (One-Time)

### 1. Install ROS 2 Humble
Follow the official [ROS 2 Humble installation guide](https://docs.ros.org/en/humble/Installation.html).

### 2. Install System Dependencies
```bash
# Ouster Drivers
sudo apt update && sudo apt install -y ros-humble-ouster-ros

# Swift Navigation SBP Library (Python 3.10)
sudo python3.10 -m pip install sbp

# Networking Tools
sudo apt install -y arp-scan linuxptp
```

---

## 🚀 Execution Guide (From Scratch)

### Step 1: Start the Master Clock
In a dedicated terminal, start the PTP sync. Leave this running the entire time.
```bash
sudo ptp4l -i enp3s0 -m -S
```

### Step 2: Initialize the Network
Run this to fix routing conflicts and isolate the sensors.
```bash
cd GNSS_Recorder
chmod +x setup_network.sh record_data.sh
./setup_network.sh
```

### Step 3: Record
One click to start the full sensor suite.
```bash
./record_data.sh
```
*Press **[Ctrl+C]** to save the bag when finished.*

---

## 📺 Viewing Data
To view your saved bags in RViz:
1. `ros2 bag play data/<bag_folder> -l`
2. Open `rviz2`.
3. Set **Fixed Frame** to `os_sensor`.
4. Add the topic `/ouster/points` and set **Reliability Policy** to `Best Effort`.

---

---

## 🕵️‍♂️ Troubleshooting: Identifying a New GNSS IP
If your new sensor is "hiding" and Swift Console can't find it via Ethernet:


### The "Boot Listener" 
1. Power off the GNSS.
2. Run: `sudo tcpdump -i <interface_name> -n arp`
3. Power on the GNSS.
4. Look for the "tell" IP: `ARP, Request who-has 192.168.0.1 tell 192.168.0.222`


---

## 🗂️ Repository Structure
- `record_data.sh`: High-level recording script.
- `setup_network.sh`: Networking/Routing fix.
- `scripts/sbp_ros2_bridge.py`: Custom Swift Binary-to-ROS 2 messenger.
- `config/ouster_params.yaml`: LiDAR metadata and settings.
- `data/`: Automated storage for your recordings.
