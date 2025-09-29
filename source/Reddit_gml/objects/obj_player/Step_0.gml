
var _input_left = keyboard_check(ord("A")) || keyboard_check(vk_left);
var _input_right = keyboard_check(ord("D")) || keyboard_check(vk_right);

var _input_h = _input_right - _input_left;

move_and_collide(_input_h * player_speed, 1 /* gravity */, obj_wall);