#!/usr/bin/env ucode
'use strict';

import { popen } from 'fs';

const output = 'tx bitrate:	86.7 MBit/s VHT-MCS 8 short GI VHT-NSS 1';

printf("Testing different regex patterns:\n\n");

printf("1. With \\s+: ");
const m1 = match(output, /tx bitrate:\s+([\d.]+)\s+MBit\/s/);
printf("%s\n", m1 ? "MATCH: " + m1[1] : "NO MATCH");

printf("2. With tab literal: ");
const m2 = match(output, /tx bitrate:	([\d.]+) MBit\/s/);
printf("%s\n", m2 ? "MATCH: " + m2[1] : "NO MATCH");

printf("3. With .+?: ");
const m3 = match(output, /tx bitrate:.+?([\d.]+) MBit\/s/);
printf("%s\n", m3 ? "MATCH: " + m3[1] : "NO MATCH");

printf("4. With [ \\t]+: ");
const m4 = match(output, /tx bitrate:[ \t]+([\d.]+) MBit\/s/);
printf("%s\n", m4 ? "MATCH: " + m4[1] : "NO MATCH");

printf("5. Split by colon: ");
const parts = split(output, ':');
if (length(parts) > 1) {
	const rateMatch = match(parts[1], /([\d.]+) MBit\/s/);
	if (rateMatch) {
		printf("MATCH: %s\n", rateMatch[1]);
	} else {
		printf("NO MATCH\n");
	}
}
