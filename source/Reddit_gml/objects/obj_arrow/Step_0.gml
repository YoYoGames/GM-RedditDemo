
// If there is no target (exit)
if (!instance_exists(target)) return;

var _time = get_timer() * 0.000001;

var _yoffset = target_yoffset + cos(_time * bounce_speed) * bounce_amount;

y = target.y + _yoffset;
x = target.x;