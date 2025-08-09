#!/bin/bash

#Path: /usr/local/bin

# Configuration
INTERFACES=("eno1" "lan0")  # Add your network interfaces here
LOG_FILE="/var/log/traffic-monitor.log"
INTERVAL=1  # Update interval in seconds

# Function to convert bytes to human readable format
human_readable() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(( bytes / 1024 ))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(( bytes / 1048576 ))MB"
    else
        echo "$(( bytes / 1073741824 ))GB"
    fi
}

# Function to get initial byte counts
get_initial_bytes() {
    local interface=$1
    local rx=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    local tx=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    echo "$rx $tx"
}

# Function to calculate speed
calculate_speed() {
    local old_bytes=$1
    local new_bytes=$2
    local interval=$3
    local speed=$(( (new_bytes - old_bytes) / interval ))
    human_readable $speed
}

# Initialize arrays for storing previous values
declare -A prev_rx prev_tx total_rx total_tx

# Get initial values
for interface in "${INTERFACES[@]}"; do
    read prev_rx[$interface] prev_tx[$interface] <<< $(get_initial_bytes $interface)
    total_rx[$interface]=${prev_rx[$interface]}
    total_tx[$interface]=${prev_tx[$interface]}
done

# Clear screen and hide cursor
clear
echo -e "\e[?25l"

# Trap CTRL+C to restore cursor and exit cleanly
trap 'echo -e "\e[?25h"; exit 0' INT

# Main monitoring loop
while true; do
    # Move cursor to top
    echo -e "\033[0;0H"
    
    echo "Network Traffic Monitor"
    echo "Press Ctrl+C to exit"
    echo "----------------------------------------"
    
    for interface in "${INTERFACES[@]}"; do
        # Get current values
        read current_rx current_tx <<< $(get_initial_bytes $interface)
        
        # Calculate speeds
        rx_speed=$(calculate_speed ${prev_rx[$interface]} $current_rx $INTERVAL)
        tx_speed=$(calculate_speed ${prev_tx[$interface]} $current_tx $INTERVAL)
        
        # Calculate totals
        total_rx_human=$(human_readable $current_rx)
        total_tx_human=$(human_readable $current_tx)
        
        # Update previous values
        prev_rx[$interface]=$current_rx
        prev_tx[$interface]=$current_tx
        
        # Display statistics
        echo "Interface: $interface"
        echo "Current Speed:"
        echo "  ↓ Download: $rx_speed/s"
        echo "  ↑ Upload:   $tx_speed/s"
        echo "Total Traffic:"
        echo "  ↓ Download: $total_rx_human"
        echo "  ↑ Upload:   $total_tx_human"
        echo "----------------------------------------"
    done
    
    sleep $INTERVAL
done
