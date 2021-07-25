tool
extends EditorPlugin

var dock
var painter_node : Painter2D
var parent_node
var sub_node
var view_transform : Transform2D
var mouse_loc_pos : Vector2
var mouse_glb_pos : Vector2

var tex_rect_collection := []


var label = Label.new()
var font = label.get_font("")


#================================= INIT ========================================
func _enter_tree():
	dock = preload("res://addons/Painter2D/painter_dock.tscn").instance()


func _exit_tree():
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()


#============================= HANDLES TOOL ====================================
func handles(object):
	var painter_selected = object is Painter2D
	if painter_selected:
		painter_node = object
		parent_node = object.get_parent()
		
		add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, dock)
	else:
		dock.is_painting = false
		dock.update_settings()
		remove_control_from_docks(dock)
	return painter_selected



#============================== GRAB INPUTS ====================================
var mouse_left_pressed := false
var mouse_right_pressed := false
var mouse_middle_pressed := false
var ctrl_pressed := false
var shift_pressed := false
var dragging := false
var spacing = 50
var prev_stored_pos : Vector2


func forward_canvas_gui_input(event):
	update_overlays()
	#--- grab the inputs only if the tool is painting
	if not dock:
		return false
	if not dock.is_painting:
		return false
	
	if event is InputEventKey:
		if event.scancode == KEY_CONTROL:
			ctrl_pressed = event.is_pressed()
		if event.scancode == KEY_SHIFT:
			shift_pressed = event.is_pressed()
	
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			mouse_left_pressed = event.is_pressed()
			if event.is_pressed():
				prev_stored_pos = overlay_pos2scene_pos(event.position)
				place_new_sprite(prev_stored_pos)
				
			elif dragging:
				dragging = false
		
		elif event.button_index == BUTTON_RIGHT:
			mouse_right_pressed = event.is_pressed()
			if event.is_pressed():
				update_tex_rect_collection()
				erase_sprites(overlay_pos2scene_pos(event.position))
		
		elif event.button_index == BUTTON_MIDDLE:
			mouse_middle_pressed = event.is_pressed()
			return false
		
		elif event.button_index == BUTTON_WHEEL_UP and event.is_pressed():
			if mouse_right_pressed:
				dock.paint_radius += 5
			elif ctrl_pressed:
				dock.custom_scale *= 1.1
			elif shift_pressed:
				dock.increase_custom_rot(PI/90)
			else:
				dock.set_next_texture()
		elif event.button_index == BUTTON_WHEEL_DOWN and event.is_pressed():
			if mouse_right_pressed:
				dock.paint_radius -= 5
			elif ctrl_pressed:
				dock.custom_scale /= 1.1
			elif shift_pressed:
				dock.increase_custom_rot(-PI/90)
			else:
				dock.set_next_texture(-1)
	if event is InputEventMouseMotion:
		if mouse_left_pressed and dock.is_painting:
			if prev_stored_pos != Vector2.ZERO:
				var dist = (overlay_pos2scene_pos(event.position) - prev_stored_pos).length()
				if dist > spacing:
					prev_stored_pos = overlay_pos2scene_pos(event.position)
					place_new_sprite(prev_stored_pos)
	
		elif mouse_right_pressed and dock.is_painting:
			erase_sprites(overlay_pos2scene_pos(event.position))
		elif mouse_middle_pressed:
			return false
	
	update_overlays()
	
	# return true to prevent the propagations of the input signals
	return true


#============================ DRAW ON SCREEN ===================================
func forward_canvas_draw_over_viewport(overlay):
	#--- global vars
	mouse_loc_pos = overlay.get_local_mouse_position()
	mouse_glb_pos = overlay.get_global_mouse_position()
	view_transform = painter_node.get_viewport_transform()
	dock.mouse_loc_pos = mouse_loc_pos
	dock.view_transform = view_transform
	dock.update_infos()
	
	if not dock.is_painting:
		return
	
	if mouse_right_pressed:
		draw_paint_circle(overlay, mouse_loc_pos)
	else:
		draw_next_texture(overlay, mouse_loc_pos)


func draw_paint_circle(overlay, pos):
	var scaled_radius = dock.paint_radius * view_transform.get_scale().x
	overlay.draw_circle(pos, scaled_radius, dock.erase_color)


func draw_next_texture(overlay, mouse_loc_pos):
	if not dock.next_texture:
#		print("Painter2D: texture missing")
		dock.set_next_texture()
		return
	var tex_size = dock.next_texture.get_size()
	var scaled_tex = tex_size * view_transform.get_scale() * (dock.custom_scale - dock.rand_scale)
	var tex_pos = mouse_loc_pos - scaled_tex/2
	if dock.offset_active:
		tex_pos -= dock.selected_tex_offset_scaled * view_transform.get_scale()
	var text_rect = Rect2(tex_pos.x, tex_pos.y, scaled_tex.x, scaled_tex.y)
#	overlay.draw_set_transform(mouse_glb_pos, PI/2, Vector2.ONE)
	overlay.draw_texture_rect(dock.next_texture, text_rect, false, Color(1,1,1,0.3))
#	overlay.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
#	overlay.draw_set_transform("pos", "rot", "scale")
	


#=============================== PAINT TOOLS ===================================
func place_new_sprite(global_pos):
	var new_sprite = Sprite.new()
	new_sprite.texture = dock.next_texture
	new_sprite.global_position = global_pos
	if dock.offset_active:
		new_sprite.offset = -dock.selected_tex_offset_scaled/(dock.custom_scale - dock.rand_scale)
	new_sprite.scale *= (dock.custom_scale - dock.rand_scale)
	new_sprite.rotation = dock.custom_rot - dock.rand_rot
	#--- custom sprite name
	if dock.custom_name != "":
		new_sprite.name = dock.custom_name
	
	#--- add to subnode
	sub_node = parent_node
	if dock.subnode_name != "":
		sub_node = parent_node.find_node(dock.subnode_name)
		if not sub_node:
			sub_node = Node2D.new()
			sub_node.name = dock.subnode_name
			parent_node.add_child(sub_node)
			sub_node.owner = painter_node.owner
	
	sub_node.add_child(new_sprite)
	new_sprite.owner = painter_node.owner
	
	dock.set_next_texture()


func erase_sprites(mouse_pos):
	if tex_rect_collection.empty():
		return
	for i in range(tex_rect_collection.size()):
		var rect: Rect2 = tex_rect_collection[i]
		print(rect, mouse_pos, rect.has_point(mouse_pos))
		if rect.has_point(mouse_pos):
			sub_node.get_child(i).free()
			tex_rect_collection.remove(i)


func overlay_pos2scene_pos(pos):
	return (pos - view_transform.get_origin()) / view_transform.get_scale().x

func update_tex_rect_collection():
	tex_rect_collection = []
	for i in range(sub_node.get_child_count()):
		var tex = sub_node.get_child(i)
		if tex is Sprite:
			print(tex.name, " ", tex.get_rect(), " ", tex.get_transform())
			var tex_size = tex.get_rect().size * tex.get_transform().get_scale()
			var tex_orig = tex.get_transform().get_origin() - tex_size/2
			var transl_rect = Rect2(tex_orig, tex_size)
			tex_rect_collection.append(transl_rect)


