# LuCI Wireless Range Test Application

A web-based wireless performance testing tool for OpenWrt access points. This application allows wireless clients to test their connection quality and throughput directly from their browser.

## Overview

`luci-app-range` provides a simple interface for wireless clients to:
- View real-time wireless connection statistics
- Test download and upload throughput
- Monitor 802.11 signal quality metrics
- See active data rates and modulation schemes

## Features

### Real-Time Connection Statistics
- **MAC Address**: Automatically detected from client IP
- **Signal Strength**: Current RSSI in dBm
- **Noise Level**: Background noise in dBm
- **TX/RX Rates**: Current transmission/reception rates with:
  - Bitrate (Mbit/s)
  - MCS index
  - Channel bandwidth (20/40/80/160 MHz)
  - Short Guard Interval (SGI) status
- **Channel**: Active wireless channel

### Throughput Testing
- **Download Test**: Transfer data from AP to client
- **Upload Test**: Transfer data from client to AP
- **Live Metrics**: Real-time speed display during tests
- **Test Duration**: Elapsed time tracking

## Installation

### Building from Source

This package must be built as part of the OpenWrt build system:

1. Clone the OpenWrt repository
2. Add this LuCI fork as a feed:
   ```bash
   # Edit feeds.conf.default
   # Comment out: src-git luci https://github.com/openwrt/luci.git
   # Add: src-link luci /path/to/this/luci/repo
   ```

3. Update and install feeds:
   ```bash
   ./scripts/feeds update luci
   ./scripts/feeds install -a -p luci
   ```

4. Select the package in menuconfig:
   ```bash
   make menuconfig
   # Navigate to: LuCI → 3. Applications → luci-app-range
   # Press 'm' to select as module
   ```

5. Build the toolchain and package:
   ```bash
   make tools/install
   make toolchain/install
   make package/luci-app-range/compile
   ```

6. Find the IPK package in `bin/packages/<arch>/luci/`

### Installing on OpenWrt Device

```bash
opkg install luci-app-range_*.ipk
```

After installation, log out and log back in to the LuCI web interface to refresh the cache.

### Installing from Git (Development)

For quick testing without building an IPK:

```bash
# Copy files to OpenWrt device (replace 192.168.1.1 with your router IP)
scp -r root/* root@192.168.1.1:/
scp -r htdocs/* root@192.168.1.1:/www/

# Restart rpcd to load new RPC scripts
ssh root@192.168.1.1 "killall -HUP rpcd"
```

Log out and log back in to the web interface.

## Usage

1. Connect to your OpenWrt AP via wireless
2. Access the LuCI web interface (typically http://192.168.1.1)
3. Navigate to **Network → Range Test**
4. The page will automatically display your connection statistics
5. Click **Start Download Test** or **Start Upload Test** to begin throughput testing
6. Click **Stop Test** to end the test early

Statistics refresh automatically every few seconds while the page is open.

## Technical Details

### Architecture

**Frontend** (`htdocs/luci-static/resources/view/range/test.js`):
- JavaScript view using LuCI's client-side framework
- Declarative RPC bindings to backend methods
- Polling-based statistics updates
- DOM manipulation via LuCI's `E()` helper

**Backend** (`root/usr/share/rpcd/ucode/range.uc`):
- ucode (JavaScript-like) RPC script
- Exposes methods via `luci.range` ubus namespace
- Parses `iw` command output for wireless statistics
- Manages test state and data transfer

### RPC Methods

All methods are in the `luci.range` namespace:

- **`get_station_info(mac)`**: Returns wireless statistics for the specified station (or auto-detects from caller's IP)
  ```javascript
  {
    mac: "aa:bb:cc:dd:ee:ff",
    interface: "wlan0",
    ssid: "MyNetwork",
    channel: 36,
    signal: -45,
    noise: -95,
    tx_rate: { rate: "866.7", mcs: 9, width: 80, short_gi: true },
    rx_rate: { rate: "866.7", mcs: 9, width: 80, short_gi: true }
  }
  ```

- **`start_test(direction)`**: Start throughput test
  - `direction`: "download" or "upload"
  - Returns: `{ success: true, message: "Test started", direction: "download" }`

- **`stop_test()`**: Stop running test
  - Returns: Test summary with duration and bytes transferred

- **`get_test_status()`**: Get current test status
  - Returns: Status, direction, speeds, and duration

- **`transfer_data(size)`**: Transfer test data (used internally by tests)

### Dependencies

- `luci-base`: Core LuCI framework
- `rpcd`: OpenWrt RPC daemon
- `rpcd-mod-iwinfo`: Wireless information module
- `iw`: Wireless configuration utility (usually pre-installed on OpenWrt)

### ACL Permissions

The application requires the following permissions (defined in `root/usr/share/rpcd/acl.d/luci-app-range.json`):

**Read access**:
- `ubus`: `luci.range.*`, `hostapd.*`, `network.wireless.*`, `iwinfo.*`
- `file`: `/usr/bin/iw`, `/sbin/iwinfo` (exec permission)

**Write access**:
- `ubus`: `luci.range.start_test`, `luci.range.stop_test`

## Application Structure

```
luci-app-range/
├── Makefile                                    # Package definition
├── README.md                                   # This file
├── htdocs/luci-static/resources/
│   └── view/range/
│       └── test.js                            # Frontend view
└── root/usr/share/
    ├── luci/menu.d/
    │   └── luci-app-range.json               # Menu entry definition
    └── rpcd/
        ├── acl.d/
        │   └── luci-app-range.json           # Access control list
        └── ucode/
            └── range.uc                       # Backend RPC script
```

## Code Style

- Uses **tabs** for indentation (OpenWrt/LuCI standard)
- ucode syntax follows JavaScript ES6 conventions
- Frontend uses LuCI's declarative patterns (RPC declarations, view.extend)

## Development

### Editing the Code

For development, you can edit files directly on the OpenWrt device or use `sshfs` to mount the filesystem:

```bash
sshfs root@192.168.1.1:/ /mnt/openwrt
```

**Frontend code location**: `/www/luci-static/resources/view/range/test.js`
**Backend code location**: `/usr/share/rpcd/ucode/range.uc`

After editing the backend, restart rpcd:
```bash
killall -HUP rpcd
```

After editing the frontend, clear your browser cache or force-refresh the page.

### Testing RPC Methods

You can test RPC methods directly via ubus:

```bash
# Get station info (replace MAC address)
ubus call luci.range get_station_info '{"mac":"aa:bb:cc:dd:ee:ff"}'

# Start download test
ubus call luci.range start_test '{"direction":"download"}'

# Get test status
ubus call luci.range get_test_status

# Stop test
ubus call luci.range stop_test
```

### Debugging

- Check rpcd logs: `logread | grep rpcd`
- Check ucode syntax: `ucode -c /usr/share/rpcd/ucode/range.uc`
- Check ACL permissions: `ubus call session access '{"ubus_rpc_session":"<session>","scope":"access-group","object":"luci-app-range"}'`

## Limitations

- Only works for wireless clients (wired clients won't have wireless statistics)
- Throughput tests are basic and may not reflect maximum achievable speeds
- Client MAC detection requires the client to be in the ARP table
- Some wireless drivers may not report all statistics

## Future Enhancements

Potential improvements:
- More sophisticated throughput testing (multiple streams, TCP window tuning)
- Historical graphs of signal strength and throughput
- Support for multiple simultaneous tests
- Export test results as JSON/CSV
- WebSocket-based real-time streaming for better throughput testing
- Support for 802.11ax (Wi-Fi 6) specific metrics

## License

GPL-2.0

## Author

Luke Jenkins

## Contributing

This is a fork of the OpenWrt LuCI repository. For contributing to upstream LuCI, see https://github.com/openwrt/luci

For issues specific to luci-app-range, please file issues in this repository.
