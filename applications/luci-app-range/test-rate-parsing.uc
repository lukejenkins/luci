#!/usr/bin/env ucode
'use strict';

import { popen } from 'fs';

const mac = '5e:94:b2:64:8c:cd';
const ifname = 'phy0-ap0';

const cmd = 'iw dev ' + ifname + ' station get ' + mac;
const proc = popen(cmd);
const output = proc.read('all');
proc.close();

printf("=== RAW OUTPUT ===\n%s\n", output);

printf("\n=== TESTING TX BITRATE REGEX ===\n");
const txMatch = match(output, /tx bitrate:\s+([\d.]+)\s+MBit\/s/);
if (txMatch) {
	printf("Match found!\n");
	printf("Full match: %s\n", txMatch[0]);
	printf("Rate: %s\n", txMatch[1]);

	// Test MCS pattern
	const mcsMatch = match(output, /tx bitrate:.*?MCS\s+(\d+)/);
	if (mcsMatch) {
		printf("MCS: %s\n", mcsMatch[1]);
	}

	// Test bandwidth
	const bwMatch = match(output, /tx bitrate:.*?(20|40|80|160)MHz/);
	if (bwMatch) {
		printf("Bandwidth: %s MHz\n", bwMatch[1]);
	}
} else {
	printf("NO MATCH!\n");
}

printf("\n=== TESTING RX BITRATE REGEX ===\n");
const rxMatch = match(output, /rx bitrate:\s+([\d.]+)\s+MBit\/s/);
if (rxMatch) {
	printf("Match found!\n");
	printf("Rate: %s\n", rxMatch[1]);
} else {
	printf("NO MATCH!\n");
}
