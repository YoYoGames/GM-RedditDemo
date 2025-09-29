
if (prev_points != points) {
	prev_points = points;
	api_save_state(0, { points }, function(_status, _ok, _result) {
		alarm[0] = 60;
	});
}
else alarm[0] = 60;