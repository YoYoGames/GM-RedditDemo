
api_submit_score(random(20000), function(_async_load) {
	show_debug_message("###### api_submit_score #####");
	show_debug_message(json_encode(_async_load));
	show_debug_message("#############################");
});