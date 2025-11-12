#!/usr/bin/env ucode

'use strict';

import { connect } from 'ubus';
import { popen } from 'fs';

const ubus = connect();

// Global test state
let testState = {
	running: false,
	direction: null,
	startTime: null,
	bytesTransferred: 0
};

// Get the client's MAC address from the HTTP request
function getClientMac(req) {
	// Try to get the client IP from the request
	const clientIp = req?.env?.REMOTE_ADDR;
	if (!clientIp) return null;

	// Query ARP table to find MAC address
	const arp = popen('ip neigh show ' + clientIp);
	if (arp) {
		const line = arp.read('all');
		arp.close();

		// Parse MAC from line like: "192.168.1.100 dev wlan0 lladdr aa:bb:cc:dd:ee:ff REACHABLE"
		const macMatch = match(line, /lladdr ([0-9a-f:]+)/i);
		if (macMatch && macMatch[1]) {
			return lc(macMatch[1]);
		}
	}

	return null;
}

// Get all connected stations
function getAllStations() {
	const stations = [];
	const interfaces = ubus.call('network.wireless', 'status', {});
	if (!interfaces) return stations;

	for (let radio in interfaces) {
		const radioInfo = interfaces[radio];
		if (!radioInfo.up || !radioInfo.interfaces) continue;

		const ifaceList = radioInfo.interfaces;
		for (let i = 0; i < length(ifaceList); i++) {
			const iface = ifaceList[i];
			if (!iface.ifname) continue;

			// Run iw to get all stations on this interface
			const cmd = 'iw dev ' + iface.ifname + ' station dump 2>/dev/null';
			const proc = popen(cmd);
			if (!proc) continue;

			const output = proc.read('all');
			proc.close();

			if (!output || length(output) == 0) continue;

			// Parse each station block
			const stationBlocks = split(output, '\nStation ');
			for (let j = 0; j < length(stationBlocks); j++) {
				const block = stationBlocks[j];
				if (length(block) < 10) continue;

				// Extract MAC from first line
				const macMatch = match(block, /^([0-9a-f:]+)/i);
				if (macMatch && macMatch[1]) {
					push(stations, {
						mac: lc(macMatch[1]),
						interface: iface.ifname
					});
				}
			}
		}
	}

	return stations;
}

// Get wireless station information using iw
function getStationInfoFromIw(mac) {
	// First, find which wireless interface the client is on
	const interfaces = ubus.call('network.wireless', 'status', {});
	if (!interfaces) return null;

	for (let radio in interfaces) {
		const radioInfo = interfaces[radio];
		if (!radioInfo.up || !radioInfo.interfaces) continue;

		const ifaceList = radioInfo.interfaces;
		for (let i = 0; i < length(ifaceList); i++) {
			const iface = ifaceList[i];
			if (!iface.ifname) continue;

			// Run iw to get station info
			const cmd = 'iw dev ' + iface.ifname + ' station get ' + mac + ' 2>/dev/null';
			const proc = popen(cmd);
			if (!proc) continue;

			const output = proc.read('all');
			proc.close();

			if (!output || length(output) == 0) continue;

			// Parse iw output
			const info = {
				mac: mac,
				interface: iface.ifname,
				ssid: iface.config?.ssid || null,
				channel: radioInfo.config?.channel || null
			};

			// Parse signal strength
			const signalMatch = match(output, /signal:\s+(-?[0-9]+)/);
			if (signalMatch && signalMatch[1]) {
				info.signal = int(signalMatch[1]);
			}

			// Parse TX rate - split by lines and find the rate line
			const lines = split(output, '\n');
			for (let i = 0; i < length(lines); i++) {
				const line = lines[i];

				if (index(line, 'tx bitrate:') >= 0) {
					// Extract rate number
					const rateMatch = match(line, /([0-9]+\.[0-9]+) MBit\/s/);
					if (rateMatch && rateMatch[1]) {
						info.tx_rate = { rate: rateMatch[1] };

						// Check for MCS
						const mcsMatch = match(line, /MCS ([0-9]+)/);
						if (mcsMatch && mcsMatch[1]) {
							info.tx_rate.mcs = int(mcsMatch[1]);
						}

						// Check for VHT-MCS (Wi-Fi 5)
						const vhtMcsMatch = match(line, /VHT-MCS ([0-9]+)/);
						if (vhtMcsMatch && vhtMcsMatch[1]) {
							info.tx_rate.mcs = int(vhtMcsMatch[1]);
							info.tx_rate.vht = true;
						}

						// Check for short GI
						if (index(line, 'short GI') >= 0) {
							info.tx_rate.short_gi = true;
						}
					}
				}

				if (index(line, 'rx bitrate:') >= 0) {
					const rateMatch = match(line, /([0-9]+\.[0-9]+) MBit\/s/);
					if (rateMatch && rateMatch[1]) {
						info.rx_rate = { rate: rateMatch[1] };

						const mcsMatch = match(line, /MCS ([0-9]+)/);
						if (mcsMatch && mcsMatch[1]) {
							info.rx_rate.mcs = int(mcsMatch[1]);
						}

						const vhtMcsMatch = match(line, /VHT-MCS ([0-9]+)/);
						if (vhtMcsMatch && vhtMcsMatch[1]) {
							info.rx_rate.mcs = int(vhtMcsMatch[1]);
							info.rx_rate.vht = true;
						}

						if (index(line, 'short GI') >= 0) {
							info.rx_rate.short_gi = true;
						}
					}
				}
			}

			// Parse noise (if available)
			const noiseMatch = match(output, /noise:\s+(-?[0-9]+)/);
			if (noiseMatch && noiseMatch[1]) {
				info.noise = int(noiseMatch[1]);
			}

			// Parse TX/RX bytes for throughput calculation
			const txBytesMatch = match(output, /tx bytes:\s+([0-9]+)/);
			if (txBytesMatch && txBytesMatch[1]) {
				info.tx_bytes = int(txBytesMatch[1]);
			}

			const rxBytesMatch = match(output, /rx bytes:\s+([0-9]+)/);
			if (rxBytesMatch && rxBytesMatch[1]) {
				info.rx_bytes = int(rxBytesMatch[1]);
			}

			return info;
		}
	}

	return null;
}

const methods = {
	get_station_info: {
		args: {
			mac: ''
		},
		call: function(req) {
			let mac = req.args?.mac || getClientMac(req);

			// If we still don't have a MAC, try to get the first connected station
			if (!mac) {
				const stations = getAllStations();
				if (length(stations) > 0) {
					mac = stations[0].mac;
				}
			}

			if (!mac) {
				return {
					error: 'No wireless clients connected'
				};
			}

			const info = getStationInfoFromIw(mac);

			if (!info) {
				return {
					error: 'Station not found or not connected to wireless',
					tried_mac: mac
				};
			}

			return info;
		}
	},

	start_test: {
		args: {
			direction: ''
		},
		call: function(req) {
			const direction = req.args?.direction;

			if (!direction || (direction != 'download' && direction != 'upload')) {
				return {
					success: false,
					error: 'Invalid direction. Must be "download" or "upload"'
				};
			}

			// Stop any existing test
			if (testState.running) {
				testState.running = false;
			}

			// Initialize new test
			testState = {
				running: true,
				direction: direction,
				startTime: time(),
				bytesTransferred: 0
			};

			return {
				success: true,
				message: 'Test started',
				direction: direction
			};
		}
	},

	stop_test: {
		call: function(req) {
			if (!testState.running) {
				return {
					success: true,
					message: 'No test was running'
				};
			}

			testState.running = false;

			const duration = time() - testState.startTime;
			const avgSpeed = duration > 0 ? testState.bytesTransferred / duration : 0;

			return {
				success: true,
				message: 'Test stopped',
				duration: duration,
				bytes_transferred: testState.bytesTransferred,
				average_speed: avgSpeed
			};
		}
	},

	get_test_status: {
		call: function(req) {
			if (!testState.running) {
				return {
					status: 'Idle',
					running: false
				};
			}

			const duration = time() - testState.startTime;
			const currentSpeed = duration > 0 ? testState.bytesTransferred / duration : 0;

			const result = {
				status: 'Running',
				running: true,
				direction: testState.direction,
				duration: duration,
				bytes_transferred: testState.bytesTransferred
			};

			if (testState.direction == 'download') {
				result.download_speed = currentSpeed;
				result.upload_speed = 0;
			} else {
				result.download_speed = 0;
				result.upload_speed = currentSpeed;
			}

			return result;
		}
	},

	// Endpoint for transferring test data
	transfer_data: {
		args: {
			size: 0
		},
		call: function(req) {
			if (!testState.running) {
				return {
					success: false,
					error: 'No test is running'
				};
			}

			const size = req.args?.size || 65536; // Default 64KB chunk
			testState.bytesTransferred += size;

			// Generate dummy data for download test
			if (testState.direction == 'download') {
				// Return a chunk of data
				let data = '';
				for (let i = 0; i < size; i++) {
					data += 'X';
				}
				return {
					success: true,
					data: data,
					bytes: size
				};
			}

			// For upload test, just acknowledge receipt
			return {
				success: true,
				bytes_received: size
			};
		}
	}
};

return { 'luci.range': methods };
