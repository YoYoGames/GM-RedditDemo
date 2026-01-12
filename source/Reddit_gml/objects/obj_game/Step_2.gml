

var _camera = view_camera[0];

var _x = obj_player.x;
var _y = obj_player.y;
var _viewmat = matrix_build_lookat(_x, _y, -10, _x, _y, 0, 0, 1, 0);
camera_set_view_mat(_camera, _viewmat);


var _w = window_get_width();
var _h = window_get_height();
if (window_width != _w || window_height != _h) {
    
    // this is stored (create event)
    window_width = _w;
    window_height = _h;
    
    // CRITICAL: match render target to window so GM doesn't stretch it
    if (surface_exists(application_surface)) {
        surface_resize(application_surface, _w, _h);
    }
    
    var _projmat = matrix_build_projection_ortho(window_get_width(), window_get_height(), 1.0, 32000.0);
    camera_set_proj_mat(_camera, _projmat);
}
    
view_camera[0] = _camera;