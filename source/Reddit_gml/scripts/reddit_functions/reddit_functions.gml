
/// @desc This function allows you to get the base url where your game is running
/// which is necessary when trying to access your reddit server side API.
function reddit_get_base_url() {
	
	static _domain = undefined;
	
	// This is cached so if we computed this already return it
	if (!is_undefined(_domain)) return _domain;
		
	// Try the built in runtime function
	_domain = url_get_domain();
	if (_domain == "localhost") {
		// This was not yet fixed (2024.13 or prev) lets use OS info
		var _info = os_get_info();
		var _href = ds_map_find_value(_info, "window.location.href");
		ds_map_destroy(_info);
		
		// We don't have OS information on this (fallback to domain)
		if (is_undefined(_href)) return _domain;
		
		// Let's try to look for 'index.html'
		var _cutoff = string_pos("index.html", _href);
		if (_cutoff == 0) {
			// Second pass lets do 'runner.html' instead
			_cutoff = string_pos("runner.html", _href);	 
			if (_cutoff == 0) return _domain; // Don't know what else more can be done here
		}
		
		// Remove everything after index.html (inclusive)
		_domain = string_delete(_href, _cutoff - 1 /* remove trailing '/' */, string_length(_href));
	}
	else {
		// Let's fetch the OS info
		var _info = os_get_info();
		var _protocol = ds_map_find_value(_info, "window.location.protocol");
		ds_map_destroy(_info);
		
		// We don't have OS information on this (fallback to 'https')
		_protocol ??= "https:";
		
		// Make sure we add the protocol to it
		_domain = $"{_protocol}//{_domain}";
	}

	return _domain;
}

/// @desc This function gives you the auth token necessary to pass into any calls to
/// your server side API. This token needs to be added the the header map following the format:
///		header_map[? "Authorization"] = $"Bearer {<token>};
function reddit_get_token() {
	static _token = undefined;
	
	if (!is_undefined(_token)) return _token;
	
	_token = "noone";
	for (var _i = 0; _i < parameter_count(); ++_i) {
		var _param = parameter_string(_i);
		if (string_starts_with(_param, "webbit_token=")) {
			_token = string_delete(_param, 1, 13);
		}
	}
	
	return _token;
}
