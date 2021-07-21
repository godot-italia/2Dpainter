tool
extends EditorPlugin

var dock
var painter_node : Painter2D
var parent_node
var view_transform : Transform2D
var mouse_loc_pos : Vector2



const sprite_dirs = ["res://entities/", "res://entities/grass/"]
var rand_sprites_collection = []
var rand_sprite_texture : Texture = load("res://entities/PH_tree_Bg00_01.png")

var label = Label.new()
var font = label.get_font("")


#================================= INIT ========================================
func _enter_tree():
	dock = preload("res://addons/Painter2D/painter_dock.tscn").instance()
	load_sprites_from_dirs()


func _exit_tree():
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()


func load_sprites_from_dirs():
	
	pass


func make_visible(visible):
	
	pass


#============================= HANDLES TOOL ====================================
func handles(object):
	var painter_selected = object is Painter2D
	if painter_selected:
		painter_node = object
		parent_node = object.get_parent()
		
		add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, dock)
	else:
		remove_control_from_docks(dock)
	return painter_selected



#============================== GRAB INPUTS ====================================
var mouse_left_pressed := false
var mouse_right_pressed := false
var mouse_middle_pressed := false
var ctrl_pressed := false
var dragging := false
var spacing = 50
var prev_stored_pos : Vector2

var mouse_event_pos : Vector2
func forward_canvas_gui_input(event):
	#--- grab the inputs only if the tool is painting
	if not dock:
		return false
	if not dock.is_painting:
		return false
	
	if event is InputEventKey:
		if event.scancode == KEY_CONTROL:
			ctrl_pressed = event.is_pressed()
	
	if event is InputEventMouseButton:
		mouse_event_pos = event.position
		if event.button_index == BUTTON_LEFT:
			mouse_left_pressed = event.is_pressed()
			if event.is_pressed():
				prev_stored_pos = overlay_pos2scene_pos(event.position)
				place_new_sprite(overlay_pos2scene_pos(event.position))
				
			elif dragging:
				dragging = false
		
		elif event.button_index == BUTTON_RIGHT:
			mouse_right_pressed = event.is_pressed()
		elif event.button_index == BUTTON_MIDDLE:
			mouse_middle_pressed = event.is_pressed()
			return false
		
		elif event.button_index == BUTTON_WHEEL_UP and event.is_pressed():
			if mouse_right_pressed:
				paint_radius_add(5)
			elif ctrl_pressed:
				sprite_custom_scale_add(0.2)
			else:
				dock.select_next_texture()
		elif event.button_index == BUTTON_WHEEL_DOWN and event.is_pressed():
			if mouse_right_pressed:
				paint_radius_add(-5)
			elif ctrl_pressed:
				sprite_custom_scale_add(-0.2)
			else:
				dock.select_next_texture()
	if event is InputEventMouseMotion:
		if mouse_left_pressed and dock.is_painting:
			if prev_stored_pos != Vector2.ZERO:
				var dist = (overlay_pos2scene_pos(event.position) - prev_stored_pos).length()
				if dist > spacing:
					prev_stored_pos = overlay_pos2scene_pos(event.position)
					place_new_sprite(prev_stored_pos)
	
		elif mouse_right_pressed and dock.is_painting:
			pass
		elif mouse_middle_pressed:
			return false
	
	update_overlays()
	
	# return true to prevent the propagations of the input signals
	return true


#============================ DRAW ON SCREEN ===================================
func forward_canvas_draw_over_viewport(overlay):
	#--- global vars
	mouse_loc_pos = overlay.get_local_mouse_position()
	view_transform = painter_node.get_viewport_transform()
	
	#--- unseful infos
	var info_text = \
"""mouse_loc_pos: %s
Painter2D.view_transf: %s
"""%[mouse_loc_pos, view_transform]

	dock.info_panel.text = info_text
	
	if not dock.is_painting:
		return
	if mouse_right_pressed:
		draw_paint_circle(overlay, mouse_loc_pos)
	else:
		draw_next_texture(overlay, mouse_loc_pos)


func draw_paint_circle(overlay, pos):
	var scaled_radius = dock.paint_radius * view_transform.get_scale().x
	overlay.draw_circle(pos, scaled_radius, dock.paint_color)
	overlay


func draw_next_texture(overlay, mouse_loc_pos):
	var tex_size = dock.next_texture.get_size()
	var scaled_tex = tex_size * view_transform.get_scale() * dock.custom_scale
	var tex_pos = mouse_loc_pos - scaled_tex/2 - dock.selected_tex_offset_scaled
	var text_rect = Rect2(tex_pos.x, tex_pos.y, scaled_tex.x, scaled_tex.y)
#	overlay.draw_set_transform(Vector2.ZERO, PI/2, Vector2.ONE)
	overlay.draw_texture_rect(dock.next_texture, text_rect, false, Color(1,1,1,0.3))
#	overlay.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
#	overlay.draw_set_transform("pos", "rot", "scale")
	


#=============================== PAINT TOOLS ===================================
func paint_radius_add(val):
	dock.paint_radius += val
func sprite_custom_scale_add(val):
	dock.custom_scale += val


func place_new_sprite(global_pos):
	var new_sprite = Sprite.new()
	new_sprite.texture = dock.next_texture
	new_sprite.global_position = global_pos - dock.selected_tex_offset_scaled
	new_sprite.scale *= dock.custom_scale
	var sub_node = parent_node.find_node("trees")
	if sub_node:
		sub_node.add_child(new_sprite)
	else:
		sub_node = Node2D.new()
		sub_node.name = "trees"
		parent_node.add_child(sub_node)
		sub_node.add_child(new_sprite)
		sub_node.owner = painter_node.owner
		
	new_sprite.owner = painter_node.owner
	dock.set_next_texture()

func overlay_pos2scene_pos(pos):
	return (pos - view_transform.get_origin()) / view_transform.get_scale().x
