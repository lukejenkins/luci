'use strict';
'require view';

return view.extend({
	render: function() {
		return E('div', {}, [
			E('h2', {}, 'Debug Page'),
			E('p', {}, 'If you can see this, the view is loading!'),
			E('p', {}, 'JavaScript is executing: ' + new Date().toString())
		]);
	}
});
