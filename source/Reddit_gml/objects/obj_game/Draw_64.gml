
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_font(fnt_default);
draw_text_ext_transformed(10, 10, $"User: {username}\nLevel:{level}\nTotal points: {points}\n", 20, 1280, 2, 2, 0);


var _x = room_width * 0.5;
var _y = room_height * 0.33;
var _scale = 2.5;
var _text = $"Click the Box";

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(c_orange);
draw_text_ext_transformed(_x + 3, _y + 3, _text, 0, 1280, _scale, _scale, 0);
draw_text_ext_transformed(_x + 3, _y - 3, _text, 0, 1280, _scale, _scale, 0);
draw_text_ext_transformed(_x + 3, _y, _text, 0, 1280, _scale, _scale, 0);

draw_text_ext_transformed(_x - 3, _y - 3, _text, 0, 1280, _scale, _scale, 0);
draw_text_ext_transformed(_x - 3, _y + 3, _text, 0, 1280, _scale, _scale, 0);
draw_text_ext_transformed(_x - 3, _y, _text, 0, 1280, _scale, _scale, 0);

draw_text_ext_transformed(_x, _y + 3, _text, 0, 1280, _scale, _scale, 0);
draw_text_ext_transformed(_x, _y - 3, _text, 0, 1280, _scale, _scale, 0);


draw_set_colour(c_white);
draw_text_ext_transformed(_x, _y, _text, 0, 1280, _scale, _scale, 0);
