

var _id = async_load[? "id"];

var _callback = ds_map_find_value(requests, _id);

if (!is_callable(_callback)) return;

_callback(async_load[? "http_status"], async_load[? "status"] >= 0, async_load[? "result"], async_load);

ds_map_delete(requests, _id);