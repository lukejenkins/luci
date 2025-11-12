#!/bin/bash
# Quick deployment script for luci-app-range testing
# Usage: ./deploy-test.sh <router-ip> [router-password]

set -e

ROUTER_IP="${1:-192.168.1.1}"
ROUTER_PASSWORD="${2}"

if [ -z "$ROUTER_IP" ]; then
	echo "Usage: $0 <router-ip> [router-password]"
	echo "Example: $0 192.168.8.1"
	exit 1
fi

echo "=========================================="
echo "Deploying luci-app-range to $ROUTER_IP"
echo "=========================================="

# Check if we can reach the router
if ! ping -c 1 -W 2 "$ROUTER_IP" > /dev/null 2>&1; then
	echo "Error: Cannot reach router at $ROUTER_IP"
	exit 1
fi

echo ""
echo "Step 1: Copying root files (RPC scripts, menu, ACL)..."
if [ -n "$ROUTER_PASSWORD" ]; then
	sshpass -p "$ROUTER_PASSWORD" scp -r root/* "root@$ROUTER_IP:/"
else
	scp -r root/* "root@$ROUTER_IP:/"
fi

echo ""
echo "Step 2: Copying htdocs files (JavaScript views)..."
if [ -n "$ROUTER_PASSWORD" ]; then
	sshpass -p "$ROUTER_PASSWORD" scp -r htdocs/* "root@$ROUTER_IP:/www/"
else
	scp -r htdocs/* "root@$ROUTER_IP:/www/"
fi

echo ""
echo "Step 3: Setting correct permissions..."
if [ -n "$ROUTER_PASSWORD" ]; then
	sshpass -p "$ROUTER_PASSWORD" ssh "root@$ROUTER_IP" "chmod +x /usr/share/rpcd/ucode/range.uc"
else
	ssh "root@$ROUTER_IP" "chmod +x /usr/share/rpcd/ucode/range.uc"
fi

echo ""
echo "Step 4: Restarting rpcd to load new RPC scripts..."
if [ -n "$ROUTER_PASSWORD" ]; then
	sshpass -p "$ROUTER_PASSWORD" ssh "root@$ROUTER_IP" "killall -HUP rpcd"
else
	ssh "root@$ROUTER_IP" "killall -HUP rpcd"
fi

echo ""
echo "=========================================="
echo "Deployment complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Log out of LuCI web interface if you're logged in"
echo "2. Log back in to refresh the cache"
echo "3. Navigate to Network → Range Test"
echo ""
echo "For debugging, SSH to the router and run:"
echo "  logread | grep rpcd"
echo "  ubus call luci.range get_station_info"
echo ""
