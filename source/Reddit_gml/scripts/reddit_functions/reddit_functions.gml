
function api_get_base_url() {
	return $"https://{url_get_domain()}";
}

function api_get_controller() {
	with (obj_http_controller) return self;
	return instance_create_depth(0, 0, 0, obj_http_controller);
}

function api_save_state(_level, _data, _callback) {
    var _url = api_get_base_url() + "/api/state";

    var _headers = ds_map_create();
    ds_map_add(_headers, "Content-Type", "application/json");

    var _body = {};
    if (is_real(_level)) _body.level = _level;
    if (is_struct(_data)) _body.data = _data;

    var _json = json_stringify(_body);
    var _req = http_request(_url, "POST", _headers, _json);

    ds_map_destroy(_headers);
	
	var _controller = api_get_controller();
	if (is_callable(_callback)) ds_map_add(_controller.requests, _req, _callback);

    return _req; // keep to match in Async HTTP event
}

function api_load_state(_callback) {
    var _url = api_get_base_url() + "/api/state";
    var _headers = ds_map_create();
    var _req = http_request(_url, "GET", _headers, "");
    ds_map_destroy(_headers);
	
	var _controller = api_get_controller();
	if (is_callable(_callback)) ds_map_add(_controller.requests, _req, _callback);
	
    return _req;
}

function api_submit_score(_score, _callback) {
    var _url = api_get_base_url() + "/api/score";

    var _headers = ds_map_create();
    ds_map_add(_headers, "Content-Type", "application/json");

    var _body = {};
	if (is_real(_score)) _body.score = _score;

    var _json = json_stringify(_body);
    var _req = http_request(_url, "POST", _headers, _json);

    ds_map_destroy(_headers);

	var _controller = api_get_controller();
	if (is_callable(_callback)) ds_map_add(_controller.requests, _req, _callback);

	return _req;
}

function api_get_leaderboard(_limit, _callback) {
    if (!is_real(_limit)) _limit = 10;
	
    var _url = api_get_base_url() + "/api/leaderboard?limit=" + string(_limit);

    var _headers = ds_map_create();
    var _req = http_request(_url, "GET", _headers, "");
    ds_map_destroy(_headers);
	
	var _controller = api_get_controller();
	if (is_callable(_callback)) ds_map_add(_controller.requests, _req, _callback);
	
    return _req;
}

