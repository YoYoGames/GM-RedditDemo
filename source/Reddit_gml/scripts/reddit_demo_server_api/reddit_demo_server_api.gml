
/// @ignore
function api_get_http_manager() {
	with (obj_http_manager) return self;
	return instance_create_depth(0, 0, 0, obj_http_manager);
}

/// @ignore
function api_register_request(_req, _callback) {
	var _manager = api_get_http_manager();
	_manager.register(_req, _callback);
}

/// @desc This function allows you to save the state for the current user.
/// For more details check the server demo implementation under the output folder:
/// <output>/<project_name>/src/server/index.ts
/// @param {Real} _level The current player level.
/// @param {Any} _data The data you want to save.
/// @param {Function} _callback The callback that you want to be executed upon task completion.
function api_save_state(_level, _data, _callback) {
		
	// Build request url
    var _url = reddit_get_base_url() + "/api/state";

	// Build request headers
    var _headers = ds_map_create();
    ds_map_add(_headers, "Content-Type", "application/json");
    ds_map_add(_headers, "Authorization", $"Bearer {reddit_get_token()}");

	// Build request body
    var _body = {};
    if (is_real(_level)) _body.level = _level;
    if (is_struct(_data)) _body.data = _data;
	
	// Make request
    var _json = json_stringify(_body);
    var _req = http_request(_url, "POST", _headers, _json);
	
	// Free memory
    ds_map_destroy(_headers);
	
	// Register request callback
	if (is_callable(_callback)) api_register_request(_req, _callback);

	return _req; // keep to match in Async HTTP event
}

/// @desc This function allows you to load the state for the current user.
/// For more details check the server demo implementation under the output folder:
/// <output>/<project_name>/src/server/index.ts
/// @param {Function} _callback The callback that you want to be executed upon task completion.
function api_load_state(_callback) {
		
	// Build request url
    var _url = reddit_get_base_url() + "/api/state";

	// Build request headers
    var _headers = ds_map_create();
	ds_map_add(_headers, "Authorization", $"Bearer {reddit_get_token()}");
	
	// Make request
    var _req = http_request(_url, "GET", _headers, "");
    
	// Free memory
	ds_map_destroy(_headers);
	
	// Register request callback
	if (is_callable(_callback)) api_register_request(_req, _callback);
	
    return _req;
}

/// @desc This function allows you to submit a new user highscore.
/// For more details check the server demo implementation under the output folder:
/// <output>/<project_name>/src/server/index.ts
/// @param {Real} _score The score to submit.
/// @param {Function} _callback The callback that you want to be executed upon task completion.
function api_submit_score(_score, _callback) {
	
	// Build request url
    var _url = reddit_get_base_url() + "/api/score";

	// Build request headers
    var _headers = ds_map_create();
    ds_map_add(_headers, "Content-Type", "application/json");
	ds_map_add(_headers, "Authorization", $"Bearer {reddit_get_token()}");

	// Build request body
    var _body = {};
	if (is_real(_score)) _body.score = _score;

	// Make request
    var _json = json_stringify(_body);
    var _req = http_request(_url, "POST", _headers, _json);
	
	// Free memory
    ds_map_destroy(_headers);

	// Register request callback
	if (is_callable(_callback)) api_register_request(_req, _callback);

	return _req;
}

/// @desc This function allows you to get the X top scores of the leaderboard.
/// For more details check the server demo implementation under the output folder:
/// <output>/<project_name>/src/server/index.ts
/// @param {Real} _limit The limit number of elements to query (ie.: the top 10, for example)
/// @param {Function} _callback The callback that you want to be executed upon task completion.
function api_get_leaderboard(_limit, _callback) {
		
	// Build request url
    if (!is_real(_limit)) _limit = 10;
	var _url = reddit_get_base_url() + "/api/leaderboard?limit=" + string(_limit);

	// Build request headers
    var _headers = ds_map_create();
	ds_map_add(_headers, "Authorization", $"Bearer {reddit_get_token()}");
		
	// Make request
    var _req = http_request(_url, "GET", _headers, "");
	
	// Free memory
	ds_map_destroy(_headers);
	
	// Register request callback
	if (is_callable(_callback)) api_register_request(_req, _callback);
	
    return _req;
}

