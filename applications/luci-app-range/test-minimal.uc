#!/usr/bin/env ucode
'use strict';

// Minimal test script to verify rpcd ucode support
const methods = {
	hello: {
		call: function(req) {
			return {
				message: "Hello from luci.range!",
				success: true
			};
		}
	}
};

return { 'luci.range': methods };
