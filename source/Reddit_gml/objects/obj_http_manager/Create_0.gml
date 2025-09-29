
// This will make sure we use the sessions' credentials
http_set_request_crossorigin("use-credentials");

/// @ignore
requests = ds_map_create();

/// @func register(_request, _callback)
/// @param {Real} _request_id The http request id to be registered (obtained from http_request).
/// @param {Function} _callback The callback to be executed when the request result comes back.
register = function(_req, _callback) {
	ds_map_add(requests, _req, _callback);
}

