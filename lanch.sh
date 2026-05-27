#!/usr/bin/env bash
# launch.sh – Build once, then launch or kill ROS2 nodes with flags
# Usage: ./launch.sh [-s] [-c] [-k]
#   -s: start servo relays
#   -c: start camera node
#   -k: kill all started processes / tmux session

# Workspace directory
WORKSPACE_DIR="/home/vmx/ROS"
SESSION="ros_launch"

# Flags
START_SERVOS=false
START_CAM=false
KILL_ALL=false
while getopts "sck" opt; do
  case ${opt} in
    s) START_SERVOS=true ;;  # -s: servo relays
    c) START_CAM=true ;;    # -c: camera node
    k) KILL_ALL=true ;;     # -k: kill all
    *) echo "Usage: $0 [-s] [-c] [-k]"; exit 1 ;;
  esac
done

# Kill logic
if [ "$KILL_ALL" = true ]; then
  if command -v tmux >/dev/null 2>&1; then
    tmux kill-session -t ${SESSION} 2>/dev/null && echo "Tmux session '${SESSION}' killed."
  else
    pkill -f "ros2 launch studica_control studica_launch.py" && echo "Studica node killed."
    pkill -f "ros2 run servo_helpers servo_relay" && echo "Servo relays killed."
    pkill -f "ros2 run usb_cam usb_cam_node" && echo "Camera node killed."
  fi
  exit 0
fi

# Build once

echo "Building workspace..."
cd ${WORKSPACE_DIR}
colcon build
source install/setup.bash

# Launch Studica once
echo "Starting Studica control server..."
(cd ${WORKSPACE_DIR} && source install/setup.bash && ros2 launch studica_control studica_launch.py) &
STUDICA_PID=$!
echo "Studica PID: ${STUDICA_PID}" 

# Small delay to ensure Studica is up before launching clients
sleep 5

# Launch servo relays if requested
if [ "$START_SERVOS" = true ]; then
  echo "Starting servo relay nodes..."
  for servo in servo1 servo2; do
    (cd ${WORKSPACE_DIR} && source install/setup.bash && ros2 run servo_helpers servo_relay --ros-args -p servo_name:=$servo) &
    echo "Started servo_relay for ${servo}" 
  done
fi

# Launch camera if requested
if [ "$START_CAM" = true ]; then
  echo "Starting camera node..."
  (cd ${WORKSPACE_DIR} && source install/setup.bash && ros2 run usb_cam usb_cam_node) &
  echo "Camera node started"
fi

echo "All requested processes launched. Use './launch.sh -k' to kill them."
