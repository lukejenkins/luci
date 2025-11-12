#!/bin/bash
# Test RPC methods directly

ROUTER_IP="${1:-192.168.1.1}"

echo "=========================================="
echo "Testing luci.range RPC methods"
echo "=========================================="

echo ""
echo "1. Testing get_test_status (should work)..."
ssh root@$ROUTER_IP "ubus call luci.range get_test_status"

echo ""
echo "2. Testing get_station_info (without MAC)..."
ssh root@$ROUTER_IP "ubus call luci.range get_station_info"

echo ""
echo "3. Checking connected wireless clients..."
ssh root@$ROUTER_IP "iw dev wlan0 station dump | head -30"

echo ""
echo "4. Checking wlan1 if exists..."
ssh root@$ROUTER_IP "iw dev wlan1 station dump 2>/dev/null | head -30"

echo ""
echo "5. Getting wireless status via ubus..."
ssh root@$ROUTER_IP "ubus call network.wireless status"

echo ""
echo "6. Checking ARP table..."
ssh root@$ROUTER_IP "ip neigh show"

echo ""
echo "7. Testing with a known MAC (if you provide one)..."
if [ ! -z "$2" ]; then
    echo "   Using MAC: $2"
    ssh root@$ROUTER_IP "ubus call luci.range get_station_info '{\"mac\":\"$2\"}'"
    echo ""
    echo "   Testing iw command directly with this MAC..."
    ssh root@$ROUTER_IP "iw dev wlan0 station get $2"
    ssh root@$ROUTER_IP "iw dev wlan1 station get $2 2>/dev/null"
else
    echo "   (Run: $0 $ROUTER_IP <mac-address> to test with specific MAC)"
fi

echo ""
echo "=========================================="
