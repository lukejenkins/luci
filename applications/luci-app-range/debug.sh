#!/bin/bash
# Debug script for luci-app-range RPC issues

ROUTER_IP="${1:-192.168.8.1}"

echo "=========================================="
echo "Debugging luci-app-range on $ROUTER_IP"
echo "=========================================="

echo ""
echo "1. Checking if range.uc file exists..."
ssh root@$ROUTER_IP "ls -la /usr/share/rpcd/ucode/range.uc" 2>&1

echo ""
echo "2. Checking file permissions..."
ssh root@$ROUTER_IP "stat /usr/share/rpcd/ucode/range.uc" 2>&1

echo ""
echo "3. Checking ucode syntax..."
ssh root@$ROUTER_IP "ucode -c /usr/share/rpcd/ucode/range.uc" 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ Syntax is valid"
else
    echo "   ✗ Syntax errors found!"
fi

echo ""
echo "4. Trying to run the script directly..."
ssh root@$ROUTER_IP "ucode /usr/share/rpcd/ucode/range.uc" 2>&1 | head -20

echo ""
echo "5. Checking if rpcd is running..."
ssh root@$ROUTER_IP "ps | grep rpcd" 2>&1

echo ""
echo "6. Checking ubus list for luci.range..."
ssh root@$ROUTER_IP "ubus list | grep -i range" 2>&1

echo ""
echo "7. Checking all luci.* objects..."
ssh root@$ROUTER_IP "ubus list | grep luci" 2>&1

echo ""
echo "8. Checking rpcd logs..."
ssh root@$ROUTER_IP "logread | grep -i rpcd | tail -20" 2>&1

echo ""
echo "9. Checking for ucode errors..."
ssh root@$ROUTER_IP "logread | grep -i ucode | tail -20" 2>&1

echo ""
echo "10. Verifying rpcd ucode plugin is installed..."
ssh root@$ROUTER_IP "opkg list-installed | grep rpcd" 2>&1

echo ""
echo "=========================================="
echo "Debug complete!"
echo "=========================================="
