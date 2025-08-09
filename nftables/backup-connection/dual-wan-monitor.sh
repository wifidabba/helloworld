#!/bin/bash

#Path: /usr/local/bin

# Configuration
ISP1_IF="eno1"
ISP2_IF="lan0"
ISP1_TABLE="1"
ISP2_TABLE="2"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/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"
TEST_HOSTS=("1.1.1.1" "8.8.8.8")
STATUS_FILE="/var/run/wan_status"
DETAILED_STATUS_FILE="/var/run/wan_detailed_status"
LOG_FILE="/var/log/wan-monitor.log"
ENV_FILE="/home/wifidabba/env/.env"

# Function to dynamically get network configuration
get_interface_config() {
    local interface="$1"
    local config=$(ip -j addr show dev "$interface" | jq -r '.[0].addr_info[0] | 
        {
            ip: .local, 
            mask: .prefixlen, 
            network: (.local + "/" + (.prefixlen | tostring)),
            gateway: (.broadcast | sub("\\.255$"; ".1"))
        }')
    
    if [ -z "$config" ]; then
        log_message "No IP configuration found for $interface"
        return 1
    fi
    
    echo "$config"
}

# Load environment variables
set -a
if [ -f "$ENV_FILE" ]; then
    . "$ENV_FILE"
else
    log_message "Warning: Environment file not found at $ENV_FILE"
fi
set +a
wd_number="${WD_NUMBER:-Unknown}"

# Function to log messages
log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
    send_notification "$message"
}

send_notification() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempting to send Slack notification: $message" >> "$LOG_FILE"

    local response=$(curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"$message $wd_number\"}" \
        --write-out '%{http_code}' \
        --silent \
        --output /tmp/slack_response \
        "$SLACK_WEBHOOK_URL")
    
    if [ "$response" != "200" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to send Slack notification (Response: $response)" >> "$LOG_FILE"
    fi
}

# Function to ensure routing tables exist
setup_routing_tables() {
    if ! grep -q "^${ISP1_TABLE} ISP1" /etc/iproute2/rt_tables; then
        echo "${ISP1_TABLE} ISP1" >> /etc/iproute2/rt_tables
    fi
    if ! grep -q "^${ISP2_TABLE} ISP2" /etc/iproute2/rt_tables; then
        echo "${ISP2_TABLE} ISP2" >> /etc/iproute2/rt_tables
    fi
    log_message "Verified routing tables configuration"
}

# Function to ensure basic network configuration
ensure_network_config() {
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Enable loose reverse path filtering
    for interface in "$ISP1_IF" "$ISP2_IF"; do
        if [ -d "/proc/sys/net/ipv4/conf/$interface" ]; then
            echo 2 > /proc/sys/net/ipv4/conf/$interface/rp_filter
            echo 1 > /proc/sys/net/ipv4/conf/$interface/force_igmp_version
        else
            log_message "Warning: Interface $interface not found"
        fi
    done
    
    log_message "Network configuration verified"
}

# Function to setup basic routing
setup_basic_routing() {
    local interface="$1"
    local gateway="$2"
    local table="$3"
    local network="$4"
    
    # Add network route
    ip route add "$network" dev "$interface" table "$table" 2>/dev/null || true
    
    # Add default route to table
    ip route add default via "$gateway" dev "$interface" table "$table" metric 100 2>/dev/null || true
    
    # Add rule for source routing
    ip rule add from "$network" table "$table" priority 100 2>/dev/null || true
    
    return 0
}

# Function to setup multipath routing
setup_multipath() {
    # Dynamically get network configurations
    local isp1_config=$(get_interface_config "$ISP1_IF")
    local isp2_config=$(get_interface_config "$ISP2_IF")
    
    if [ -z "$isp1_config" ] || [ -z "$isp2_config" ]; then
        log_message "Cannot setup multipath - missing network configuration"
        return 1
    fi
    
    # Parse configurations
    local ISP1_NET=$(echo "$isp1_config" | jq -r '.network')
    local ISP1_GW=$(echo "$isp1_config" | jq -r '.gateway')
    local ISP2_NET=$(echo "$isp2_config" | jq -r '.network')
    local ISP2_GW=$(echo "$isp2_config" | jq -r '.gateway')
    
    # Clean existing routes
    ip route flush table "$ISP1_TABLE"
    ip route flush table "$ISP2_TABLE"
    
    # Setup basic routing for both ISPs
    setup_basic_routing "$ISP1_IF" "$ISP1_GW" "$ISP1_TABLE" "$ISP1_NET"
    setup_basic_routing "$ISP2_IF" "$ISP2_GW" "$ISP2_TABLE" "$ISP2_NET"
    
    # Setup multipath default route with metrics
    ip route replace default \
        nexthop via "$ISP1_GW" dev "$ISP1_IF" weight 1 \
        nexthop via "$ISP2_GW" dev "$ISP2_IF" weight 1
    
    log_message "Multipath routing setup completed for $ISP1_NET and $ISP2_NET"
    return 0
}

# Function to setup single ISP
setup_single_isp() {
    local interface="$1"
    
    # Dynamically get network configuration
    local isp_config=$(get_interface_config "$interface")
    
    if [ -z "$isp_config" ]; then
        log_message "Cannot setup single ISP - missing network configuration"
        return 1
    fi
    
    # Parse configuration
    local ISP_NET=$(echo "$isp_config" | jq -r '.network')
    local ISP_GW=$(echo "$isp_config" | jq -r '.gateway')
    local table=$([ "$interface" == "$ISP1_IF" ] && echo "$ISP1_TABLE" || echo "$ISP2_TABLE")
    
    # Flush all routes
    ip route flush table "$ISP1_TABLE"
    ip route flush table "$ISP2_TABLE"
    ip route flush cache
    
    # Remove default route
    ip route del default 2>/dev/null || true
    
    # Setup basic routing
    setup_basic_routing "$interface" "$ISP_GW" "$table" "$ISP_NET"
    
    # Add new default route
    ip route add default via "$ISP_GW" dev "$interface" metric 100
    
    log_message "Single ISP routing setup completed for $interface"
    return 0
}

# Function to check gateway status
check_gateway() {
    local gateway="$1"
    local interface="$2"
    ping -I "$interface" -c 2 -W 2 "$gateway" > /dev/null 2>&1
    return $?
}

# Function to check internet connectivity
check_internet() {
    local interface="$1"
    local success=0
    
    for host in "${TEST_HOSTS[@]}"; do
        if ping -I "$interface" -c 2 -W 2 "$host" > /dev/null 2>&1; then
            success=1
            break
        fi
    done
    
    return $(( ! success ))
}

# Initialize
log_message "Starting WAN monitor..."
setup_routing_tables
ensure_network_config

# Remove status files
rm -f /tmp/isp1_down /tmp/isp2_down /tmp/load_balance_active

# Main monitoring loop
while true; do
    # Dynamically get gateways
    ISP1_GW=$(get_interface_config "$ISP1_IF" | jq -r '.gateway')
    ISP2_GW=$(get_interface_config "$ISP2_IF" | jq -r '.gateway')
    
    # Check both gateway and internet connectivity
    isp1_gw_status=$(check_gateway "$ISP1_GW" "$ISP1_IF"; echo $?)
    isp2_gw_status=$(check_gateway "$ISP2_GW" "$ISP2_IF"; echo $?)
    
    if [ $isp1_gw_status -eq 0 ]; then
        isp1_net_status=$(check_internet "$ISP1_IF"; echo $?)
    else
        isp1_net_status=1
    fi
    
    if [ $isp2_gw_status -eq 0 ]; then
        isp2_net_status=$(check_internet "$ISP2_IF"; echo $?)
    else
        isp2_net_status=1
    fi
    
    # Update routing based on status
    if [ $isp1_net_status -eq 0 ] && [ $isp2_net_status -eq 0 ]; then
        if [ ! -f /tmp/load_balance_active ]; then
            setup_multipath
            touch /tmp/load_balance_active
            rm -f /tmp/isp1_down /tmp/isp2_down
            log_message "Both ISPs online - Load balancing activated"
        fi
    elif [ $isp1_net_status -eq 0 ] && [ $isp2_net_status -ne 0 ]; then
        if [ ! -f /tmp/isp1_down ]; then
            setup_single_isp "$ISP1_IF"
            touch /tmp/isp2_down
            rm -f /tmp/load_balance_active /tmp/isp1_down
            log_message "Using ISP1 only"
        fi
    elif [ $isp1_net_status -ne 0 ] && [ $isp2_net_status -eq 0 ]; then
        if [ ! -f /tmp/isp2_down ]; then
            setup_single_isp "$ISP2_IF"
            touch /tmp/isp1_down
            rm -f /tmp/load_balance_active /tmp/isp2_down
            log_message "Using ISP2 only"
        fi
    else
        log_message "WARNING: Both ISPs offline!"
    fi
    
    # Update detailed status
    {
        echo "=== WAN Status Report ==="
        echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        echo "ISP1 ($ISP1_IF):"
        echo "Gateway: $([ $isp1_gw_status -eq 0 ] && echo "✅" || echo "❌") $ISP1_GW"
        echo "Internet: $([ $isp1_net_status -eq 0 ] && echo "✅" || echo "❌")"
        echo "Routes in table ISP1:"
        ip route show table "$ISP1_TABLE"
        echo
        echo "ISP2 ($ISP2_IF):"
        echo "Gateway: $([ $isp2_gw_status -eq 0 ] && echo "✅" || echo "❌") $ISP2_GW"
        echo "Internet: $([ $isp2_net_status -eq 0 ] && echo "✅" || echo "❌")"
        echo "Routes in table ISP2:"
        ip route show table "$ISP2_TABLE"
        echo
        echo "Main routing table:"
        ip route show
        echo
        echo "IP Rules:"
        ip rule show
    } > "$DETAILED_STATUS_FILE"
    
    sleep 30
done
