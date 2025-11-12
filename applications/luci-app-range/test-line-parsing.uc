#!/usr/bin/env ucode
'use strict';

import { popen } from 'fs';

const mac = '5e:94:b2:64:8c:cd';
const ifname = 'phy0-ap0';

const cmd = 'iw dev ' + ifname + ' station get ' + mac;
const proc = popen(cmd);
const output = proc.read('all');
proc.close();

printf("=== SPLITTING BY LINES ===\n");
const lines = split(output, '\n');
printf("Total lines: %d\n\n", length(lines));

for (let i = 0; i < length(lines); i++) {
	const line = lines[i];
	printf("Line %d: [%s]\n", i, line);

	if (index(line, 'tx bitrate:') >= 0) {
		printf("  >>> FOUND TX BITRATE LINE\n");
		const rateMatch = match(line, /([\d.]+) MBit\/s/);
		printf("  >>> Rate match: %s\n", rateMatch ? rateMatch[1] : "NO MATCH");
	}

	if (index(line, 'rx bitrate:') >= 0) {
		printf("  >>> FOUND RX BITRATE LINE\n");
		const rateMatch = match(line, /([\d.]+) MBit\/s/);
		printf("  >>> Rate match: %s\n", rateMatch ? rateMatch[1] : "NO MATCH");
	}
}
