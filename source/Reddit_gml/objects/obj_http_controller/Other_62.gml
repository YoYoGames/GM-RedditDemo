
var _id = async_load[? "id"];
var _callback = requests[? _id];

if (!is_callable(_callback)) return;

_callback(async_load);

ds_map_delete(requests, _id);