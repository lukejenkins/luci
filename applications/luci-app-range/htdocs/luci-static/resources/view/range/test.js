'use strict';
'require view';
'require rpc';
'require ui';
'require poll';

// Version tracking for cache debugging
const APP_VERSION = '1.5';

// RPC declarations for range test operations
var callGetStationInfo = rpc.declare({
	object: 'luci.range',
	method: 'get_station_info',
	params: ['mac']
});

var callStartTest = rpc.declare({
	object: 'luci.range',
	method: 'start_test',
	params: ['direction']
});

var callStopTest = rpc.declare({
	object: 'luci.range',
	method: 'stop_test'
});

var callGetTestStatus = rpc.declare({
	object: 'luci.range',
	method: 'get_test_status'
});

var callTransferData = rpc.declare({
	object: 'luci.range',
	method: 'transfer_data',
	params: ['size']
});

return view.extend({
	transferInterval: null,

	load: function() {
		console.log('[v' + APP_VERSION + '] Loading Range Test page');
		return Promise.all([
			callGetStationInfo('').then(function(result) {
				console.log('[v' + APP_VERSION + '] Load: callGetStationInfo result:', result);
				return result;
			}).catch(function(err) {
				console.error('[v' + APP_VERSION + '] Load: callGetStationInfo error:', err);
				return { error: err.message || 'Unknown error' };
			})
		]);
	},

	render: function(data) {
		var stationInfo = data[0];

		var m, s, o;

		m = E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, [
				_('Wireless Range Test'),
				' ',
				E('small', { 'style': 'color: #999; font-size: 0.6em;' }, '(v' + APP_VERSION + ')')
			]),
			E('div', { 'class': 'cbi-map-descr' },
				_('Test your wireless connection performance and view signal quality metrics.'))
		]);

		// Get initial values or defaults
		var initialMac = (stationInfo && !stationInfo.error) ? stationInfo.mac : '-';
		var initialSignal = (stationInfo && !stationInfo.error && stationInfo.signal) ? stationInfo.signal + ' dBm' : '-';
		var initialNoise = (stationInfo && !stationInfo.error && stationInfo.noise) ? stationInfo.noise + ' dBm' : '-';
		var initialTxRate = (stationInfo && !stationInfo.error && stationInfo.tx_rate) ? this.formatRate(stationInfo.tx_rate) : '-';
		var initialRxRate = (stationInfo && !stationInfo.error && stationInfo.rx_rate) ? this.formatRate(stationInfo.rx_rate) : '-';
		var initialChannel = (stationInfo && !stationInfo.error && stationInfo.channel) ? stationInfo.channel : '-';

		// Debug info for troubleshooting
		if (stationInfo && stationInfo.error) {
			m.appendChild(E('div', { 'class': 'alert-message warning' }, [
				E('h4', {}, _('Debug Info')),
				E('p', {}, _('Error: ') + stationInfo.error),
				E('p', {}, _('Check browser console for more details (F12)'))
			]));
		}

		// Station Information Section
		var stationSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('Connection Information')),
			E('div', { 'class': 'cbi-section-node' }, [
				E('div', { 'class': 'table' }, [
					E('div', { 'class': 'tr' }, [
						E('div', { 'class': 'td left', 'style': 'font-weight: bold' }, _('MAC Address:')),
						E('div', { 'class': 'td left', 'id': 'station-mac' }, initialMac)
					]),
					E('div', { 'class': 'tr' }, [
						E('div', { 'class': 'td left', 'style': 'font-weight: bold' }, _('Signal:')),
						E('div', { 'class': 'td left', 'id': 'station-signal' }, initialSignal)
					]),
					E('div', { 'class': 'tr' }, [
						E('div', { 'class': 'td left', 'style': 'font-weight: bold' }, _('Noise:')),
						E('div', { 'class': 'td left', 'id': 'station-noise' }, initialNoise)
					]),
					E('div', { 'class': 'tr' }, [
						E('div', { 'class': 'td left', 'style': 'font-weight: bold' }, _('TX Rate:')),
						E('div', { 'class': 'td left', 'id': 'station-tx-rate' }, initialTxRate)
					]),
					E('div', { 'class': 'tr' }, [
						E('div', { 'class': 'td left', 'style': 'font-weight: bold' }, _('RX Rate:')),
						E('div', { 'class': 'td left', 'id': 'station-rx-rate' }, initialRxRate)
					]),
					E('div', { 'class': 'tr' }, [
						E('div', { 'class': 'td left', 'style': 'font-weight: bold' }, _('Channel:')),
						E('div', { 'class': 'td left', 'id': 'station-channel' }, initialChannel)
					])
				])
			])
		]);

		// Test Control Section
		var testSection = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, _('Throughput Test')),
			E('div', { 'class': 'cbi-section-node' }, [
				E('div', { 'class': 'table' }, [
					E('div', { 'class': 'tr' }, [
						E('div', { 'class': 'td left', 'style': 'font-weight: bold' }, _('Test Status:')),
						E('div', { 'class': 'td left', 'id': 'test-status' }, _('Idle'))
					]),
					E('div', { 'class': 'tr' }, [
						E('div', { 'class': 'td left', 'style': 'font-weight: bold' }, _('Download Speed:')),
						E('div', { 'class': 'td left', 'id': 'download-speed' }, '-')
					]),
					E('div', { 'class': 'tr' }, [
						E('div', { 'class': 'td left', 'style': 'font-weight: bold' }, _('Upload Speed:')),
						E('div', { 'class': 'td left', 'id': 'upload-speed' }, '-')
					]),
					E('div', { 'class': 'tr' }, [
						E('div', { 'class': 'td left', 'style': 'font-weight: bold' }, _('Test Duration:')),
						E('div', { 'class': 'td left', 'id': 'test-duration' }, '-')
					])
				]),
				E('div', { 'class': 'cbi-section-node', 'style': 'margin-top: 1em' }, [
					E('button', {
						'class': 'cbi-button cbi-button-action',
						'id': 'btn-start-download',
						'click': ui.createHandlerFn(this, function() {
							return this.startTest('download');
						})
					}, _('Start Download Test')),
					' ',
					E('button', {
						'class': 'cbi-button cbi-button-action',
						'id': 'btn-start-upload',
						'click': ui.createHandlerFn(this, function() {
							return this.startTest('upload');
						})
					}, _('Start Upload Test')),
					' ',
					E('button', {
						'class': 'cbi-button cbi-button-negative',
						'id': 'btn-stop',
						'click': ui.createHandlerFn(this, function() {
							return this.stopTest();
						})
					}, _('Stop Test'))
				])
			])
		]);

		m.appendChild(stationSection);
		m.appendChild(testSection);

		// Start polling for updates
		poll.add(L.bind(this.updateStats, this));

		return m;
	},

	startTest: function(direction) {
		ui.showModal(_('Starting Test'), [
			E('p', { 'class': 'spinning' }, _('Initializing test...'))
		]);

		return callStartTest(direction).then(L.bind(function(result) {
			ui.hideModal();
			if (result && result.success) {
				ui.addNotification(null, E('p', _('Test started successfully')), 'info');
				// Start data transfer loop
				this.startTransferLoop();
			} else {
				ui.addNotification(null, E('p', _('Failed to start test: ') + (result.error || 'Unknown error')), 'error');
			}
		}, this)).catch(function(err) {
			ui.hideModal();
			ui.addNotification(null, E('p', _('Error starting test: ') + err.message), 'error');
		});
	},

	startTransferLoop: function() {
		// Clear any existing interval
		if (this.transferInterval) {
			clearInterval(this.transferInterval);
		}

		console.log('[v' + APP_VERSION + '] Starting transfer loop');

		// Transfer 64KB chunks every 100ms (640 KB/s baseline)
		this.transferInterval = setInterval(L.bind(function() {
			console.log('[v' + APP_VERSION + '] Calling transfer_data...');
			callTransferData(65536).then(function(result) {
				console.log('[v' + APP_VERSION + '] Transfer result:', result);
			}).catch(function(err) {
				// Test might have stopped, ignore errors
				console.log('[v' + APP_VERSION + '] Transfer error:', err);
			});
		}, this), 100);
	},

	stopTransferLoop: function() {
		console.log('[v' + APP_VERSION + '] Stopping transfer loop');
		if (this.transferInterval) {
			clearInterval(this.transferInterval);
			this.transferInterval = null;
		}
	},

	stopTest: function() {
		// Stop the transfer loop
		this.stopTransferLoop();

		return callStopTest().then(L.bind(function(result) {
			if (result && result.success) {
				ui.addNotification(null, E('p', _('Test stopped')), 'info');
			}
		}, this)).catch(function(err) {
			ui.addNotification(null, E('p', _('Error stopping test: ') + err.message), 'error');
		});
	},

	updateStats: function() {
		return Promise.all([
			callGetStationInfo(''),
			callGetTestStatus()
		]).then(L.bind(function(results) {
			var stationInfo = results[0];
			var testStatus = results[1];

			console.log('[v' + APP_VERSION + '] UpdateStats: stationInfo =', stationInfo);
			console.log('[v' + APP_VERSION + '] UpdateStats: testStatus =', testStatus);

			// Update station information
			if (stationInfo && !stationInfo.error) {
				var macEl = document.getElementById('station-mac');
				var signalEl = document.getElementById('station-signal');
				var noiseEl = document.getElementById('station-noise');
				var txRateEl = document.getElementById('station-tx-rate');
				var rxRateEl = document.getElementById('station-rx-rate');
				var channelEl = document.getElementById('station-channel');

				if (macEl) macEl.textContent = stationInfo.mac || '-';
				if (signalEl) signalEl.textContent = stationInfo.signal ? stationInfo.signal + ' dBm' : '-';
				if (noiseEl) noiseEl.textContent = stationInfo.noise ? stationInfo.noise + ' dBm' : '-';
				if (txRateEl) txRateEl.textContent = stationInfo.tx_rate ? this.formatRate(stationInfo.tx_rate) : '-';
				if (rxRateEl) rxRateEl.textContent = stationInfo.rx_rate ? this.formatRate(stationInfo.rx_rate) : '-';
				if (channelEl) channelEl.textContent = stationInfo.channel ? stationInfo.channel : '-';
			} else if (stationInfo && stationInfo.error) {
				console.log('[v' + APP_VERSION + '] Station info error:', stationInfo.error);
			}

			// Update test status
			if (testStatus) {
				var statusEl = document.getElementById('test-status');
				var downloadEl = document.getElementById('download-speed');
				var uploadEl = document.getElementById('upload-speed');
				var durationEl = document.getElementById('test-duration');

				if (statusEl) statusEl.textContent = testStatus.status || 'Idle';
				if (downloadEl) downloadEl.textContent = (testStatus.download_speed !== undefined && testStatus.download_speed !== null) ? this.formatSpeed(testStatus.download_speed) : '-';
				if (uploadEl) uploadEl.textContent = (testStatus.upload_speed !== undefined && testStatus.upload_speed !== null) ? this.formatSpeed(testStatus.upload_speed) : '-';
				if (durationEl) durationEl.textContent = testStatus.duration !== undefined ? testStatus.duration + ' s' : '-';
			}
		}, this)).catch(function(err) {
			console.error('Error updating stats:', err);
		});
	},

	formatRate: function(rate) {
		if (!rate) return '-';
		var rateInfo = rate.rate ? rate.rate + ' Mbit/s' : '';
		if (rate.mcs !== undefined) {
			rateInfo += ' (MCS ' + rate.mcs + ')';
		}
		if (rate.width) {
			rateInfo += ' ' + rate.width + ' MHz';
		}
		if (rate.short_gi) {
			rateInfo += ' SGI';
		}
		return rateInfo;
	},

	formatSpeed: function(bytesPerSec) {
		if (bytesPerSec === undefined || bytesPerSec === null) return '-';
		var mbits = (bytesPerSec * 8) / 1000000;
		return mbits.toFixed(2) + ' Mbit/s';
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
