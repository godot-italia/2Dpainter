#=============================================================================#
#                    painter2D.gd - EditorPlugin                              #
#=============================================================================#
# PAINTER plug-in created by Dario "iRad" De Vita, released under MIT licence
# Release for Godot 3.3.* on July 2021
#
# This plugin is made of three component:
# - an EditorPlugin script (this one) that handles the input grab and drawing on
#    the overlay of the editorn main 2D viewport
# - a dock that derives from a Control node and keep the settings in variables
# - a Painter2D node that needs to be added to the scene and activate the dock
#    once selected. It also stores the settings in its exposed vars
#=============================================================================#


tool
extends EditorPlugin


var dock_preload = preload("res://addons/Painter2D/painter_dock.tscn")
var dock = null
var dock_is_active := false
var painter_node : Painter2D
var parent_node
var sub_node
var view_transform : Transform2D
var mouse_loc_pos : Vector2
var mouse_glb_pos : Vector2

#--- vars for erase function
var tex_rect_collection := []



#================================= INIT ========================================
func _enter_tree():
	dock = dock_preload.instance()


func _exit_tree():
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()


#============================= HANDLES TOOL ====================================

# Handles func activate every time a node is selected and pass it as an object.
# In this function if a Painter2D node is selected:
#  - the dock displays,
#  - the parent node of the painter node and the painter node get referenced
# else:
# - if a painter node reference was passed in dock, save the dock settings to it
# The functions return true to call forward_inputs and forward_canvas
func handles(object):
	#- save settings from dock to painter node if it was just active
	var painter_selected = object is Painter2D
	
	if dock_is_active:
		dock.is_painting = false
		dock.save_to_painter_node()
		dock.update_settings()
	elif painter_selected:
		dock = dock_preload.instance()
		add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, dock)
	
	
	if painter_selected:
		painter_node = object
		parent_node = object.get_parent()
		
		if object != dock.painter_node:
#			if dock.painter_node:
#				dock.save_to_painter_node()
			dock.painter_node = painter_node
#			yield(get_tree(), "idle_frame")
			dock.load_from_painter_node()
	elif dock_is_active:
		remove_control_from_docks(dock)
		dock.queue_free()
	
	dock_is_active = painter_selected
	return painter_selected



#============================== GRAB INPUTS ====================================
var mouse_left_pressed := false
var mouse_right_pressed := false
var mouse_middle_pressed := false
var ctrl_pressed := false
var shift_pressed := false
var dragging := false
var prev_stored_pos : Vector2


func forward_canvas_gui_input(event):
	update_overlays()
	#--- grab the inputs only if the tool is painting
	if not dock:
		return false
	if not dock.is_painting:
		return false
	if dock.tex_collection.empty() or dock.tex_collection_selected_ids.empty():
		return false
	
	if event is InputEventKey:
		if event.scancode == KEY_CONTROL:
			ctrl_pressed = event.is_pressed()
		if event.scancode == KEY_SHIFT:
			shift_pressed = event.is_pressed()
		
		#- dock setting higlights
		dock.highlight_spacing(not mouse_right_pressed and ctrl_pressed and shift_pressed)
		dock.highlight_scale(not mouse_right_pressed and ctrl_pressed and not shift_pressed)
		dock.highlight_rotation(not mouse_right_pressed and not ctrl_pressed and shift_pressed)
	
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
				dock.erase_radius += 5
			elif ctrl_pressed and shift_pressed:
				dock.spacing += 1
			elif ctrl_pressed:
				dock.custom_scale *= 1.1
			elif shift_pressed:
				dock.increase_custom_rot(PI/90)
			else:
				dock.set_next_texture()
		elif event.button_index == BUTTON_WHEEL_DOWN and event.is_pressed():
			if mouse_right_pressed:
				dock.erase_radius -= 5
			elif ctrl_pressed and shift_pressed:
				dock.spacing -= 1
			elif ctrl_pressed:
				dock.custom_scale /= 1.1
			elif shift_pressed:
				dock.increase_custom_rot(-PI/90)
			else:
				dock.set_next_texture(-1)
		
		dock.highlight_erase(mouse_right_pressed)
		
	if event is InputEventMouseMotion:
		if mouse_left_pressed and dock.is_painting:
			var dist = (overlay_pos2scene_pos(event.position) - prev_stored_pos).length()
			if dist > dock.spacing:
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
	if dock.tex_collection.empty() or dock.tex_collection_selected_ids.empty():
		return
	
	if mouse_right_pressed:
		draw_paint_circle(overlay, mouse_loc_pos)
		draw_sprites_erase_box(overlay)
	else:
		draw_next_texture(overlay, mouse_loc_pos)


func draw_paint_circle(overlay : Control, pos : Vector2):
	if dock.precise_erasing:
		var scaled_radius = dock.erase_radius * view_transform.get_scale().x
		overlay.draw_circle(pos, scaled_radius, dock.erase_color)
	else:
		var erase_rect : Rect2
		erase_rect.size = Vector2(dock.erase_radius, dock.erase_radius) * view_transform.get_scale()
		erase_rect.position = pos - erase_rect.size/2
		overlay.draw_rect(erase_rect, dock.erase_color)


func draw_next_texture(overlay, mouse_loc_pos):
	if not dock.next_texture:
		dock.set_next_texture()
		return
	var tex_size = dock.next_texture.get_size()
	var scaled_tex = tex_size * view_transform.get_scale() * (dock.custom_scale - dock.rand_scale)
	var tex_pos = -scaled_tex/2
	if dock.offset_active:
		tex_pos -= dock.selected_tex_offset_scaled * view_transform.get_scale()
	var text_rect = Rect2(tex_pos.x, tex_pos.y, scaled_tex.x, scaled_tex.y)
	var tex_rot = dock.custom_rot - dock.rand_rot
	overlay.draw_set_transform(mouse_loc_pos, tex_rot, Vector2.ONE)
	overlay.draw_texture_rect(dock.next_texture, text_rect, false, Color(1,1,1,0.3))
	overlay.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func draw_sprites_erase_box(overlay : Control):
	if not tex_rect_collection.empty():
		for rect in tex_rect_collection:
			var drawn_rect : Rect2 = rect
			drawn_rect.size *= view_transform.get_scale()
			drawn_rect.position *= view_transform.get_scale()
			drawn_rect.position += view_transform.origin
			overlay.draw_rect(drawn_rect, Color(0,1,1,0.3))


#=============================== PAINT TOOLS ===================================
# This function is called every time the left mouse is clicked or dragged while painting
func place_new_sprite(global_pos):
	var new_sprite = Sprite.new()
	new_sprite.texture = dock.next_texture
	new_sprite.global_position = global_pos
	if dock.offset_active:
		new_sprite.offset = -dock.selected_tex_offset_scaled/(dock.custom_scale - dock.rand_scale)
	new_sprite.scale *= (dock.custom_scale - dock.rand_scale)
	new_sprite.rotation = (dock.custom_rot - dock.rand_rot)
	#--- custom sprite name
	if dock.custom_name != "":
		new_sprite.name = dock.custom_name
	
	#--- add to subnode
	get_subnode()
	sub_node.add_child(new_sprite)
	new_sprite.owner = painter_node.owner
	
	dock.set_next_texture()


# This function is called every time the right mouse click is dragged
func erase_sprites(mouse_pos):
	if tex_rect_collection.empty():
		return
	var erase_rect : Rect2
	erase_rect.size = Vector2(dock.erase_radius, dock.erase_radius)
	erase_rect.position = mouse_pos - erase_rect.size/2
	for i in range(tex_rect_collection.size()):
		var rect: Rect2 = tex_rect_collection[i]
		rect.intersects(erase_rect)
		if rect.intersects(erase_rect):
			sub_node.get_child(i).free()
			tex_rect_collection.remove(i)
			break


# This function is called every time the erase action is activated (right mouse click)
func update_tex_rect_collection():
	tex_rect_collection = []
	get_subnode()
	for i in range(sub_node.get_child_count()):
		var tex = sub_node.get_child(i)
		var transl_rect = Rect2()
		# nodes that are not sprites get a rect with a position at -1 million px as a workaround
		transl_rect.position = Vector2.ONE*(-1000000)
		if tex is Sprite:
			var tex_size = tex.get_rect().size * tex.get_transform().get_scale()
			var tex_offset = tex.offset * tex.get_transform().get_scale()
			tex_offset = tex_offset.rotated(tex.global_rotation)
			var tex_orig = tex.get_transform().get_origin() - tex_size/2 + tex_offset
			transl_rect = Rect2(tex_orig, tex_size)
		tex_rect_collection.append(transl_rect)


# This function transform the overlay pos in a global pos in the scene
func overlay_pos2scene_pos(pos):
	return (pos - view_transform.get_origin()) / view_transform.get_scale().x


# This func find a subnode which will be the parent for the new attached sprites
func get_subnode():
	sub_node = parent_node
	if dock.subnode_name != "":
		sub_node = parent_node.find_node(dock.subnode_name)
		if not sub_node:
			sub_node = Node2D.new()
			sub_node.name = dock.subnode_name
			parent_node.add_child(sub_node)
			sub_node.owner = painter_node.owner
