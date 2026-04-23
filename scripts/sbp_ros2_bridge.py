#!/usr/bin/env python3.10
"""
SBP-to-ROS2 Bridge for Swift Navigation GNSS Receiver
Reads Swift Binary Protocol (SBP) directly from the receiver and
publishes sensor_msgs/NavSatFix messages to the /fix topic.

This replaces gpsd_client which cannot decode the SBP binary format.
"""
import sys
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import NavSatFix, NavSatStatus
from std_msgs.msg import Header

from sbp.client.drivers.network_drivers import TCPDriver
from sbp.client import Handler, Framer
from sbp.navigation import SBP_MSG_POS_LLH, MsgPosLLH

import threading

GNSS_IP = "169.254.56.64"
GNSS_PORT = 55555

class SBPBridgeNode(Node):
    def __init__(self):
        super().__init__('sbp_gnss_bridge')
        self.pub = self.create_publisher(NavSatFix, '/fix', 10)
        self.get_logger().info(f'SBP Bridge started. Connecting to {GNSS_IP}:{GNSS_PORT}...')

        # Run the SBP reader in a background thread
        self.thread = threading.Thread(target=self._read_sbp, daemon=True)
        self.thread.start()

    def _read_sbp(self):
        try:
            with TCPDriver(GNSS_IP, GNSS_PORT) as driver:
                with Handler(Framer(driver.read, None, verbose=False)) as source:
                    self.get_logger().info('Connected to Swift GNSS receiver!')
                    for msg, metadata in source.filter(SBP_MSG_POS_LLH):
                        if not rclpy.ok():
                            break
                        self._publish_fix(msg)
        except Exception as e:
            self.get_logger().error(f'SBP connection error: {e}')

    def _publish_fix(self, msg: MsgPosLLH):
        fix = NavSatFix()
        fix.header = Header()
        fix.header.stamp = self.get_clock().now().to_msg()
        fix.header.frame_id = 'gps'

        # Decode fix mode from flags
        fix_mode = msg.flags & 0x7
        if fix_mode == 0:
            fix.status.status = NavSatStatus.STATUS_NO_FIX
        elif fix_mode >= 1:
            fix.status.status = NavSatStatus.STATUS_FIX

        fix.status.service = NavSatStatus.SERVICE_GPS

        fix.latitude = msg.lat
        fix.longitude = msg.lon
        fix.altitude = msg.height

        # Covariance: use horizontal accuracy from SBP (h_accuracy in mm -> m^2)
        h_acc = (msg.h_accuracy / 1000.0) ** 2 if msg.h_accuracy > 0 else 1.0
        v_acc = (msg.v_accuracy / 1000.0) ** 2 if msg.v_accuracy > 0 else 1.0
        fix.position_covariance = [h_acc, 0.0, 0.0,
                                    0.0, h_acc, 0.0,
                                    0.0, 0.0, v_acc]
        fix.position_covariance_type = NavSatFix.COVARIANCE_TYPE_DIAGONAL_KNOWN

        self.pub.publish(fix)


def main():
    rclpy.init()
    node = SBPBridgeNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
