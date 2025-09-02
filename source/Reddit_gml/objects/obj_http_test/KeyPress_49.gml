
api_save_state(irandom(10), { name: choose("a", "b", "c"), points: irandom(100) }, function(_async_load) {
	show_debug_message("###### api_save_state #######");
	show_debug_message(json_encode(_async_load));
	show_debug_message("#############################");
});