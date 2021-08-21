#===============================#
#       painter_dock.gd         #
#===============================#

tool
extends VBoxContainer

var mouse_loc_pos
var view_transform
var painter_node = null

var mode = NextMode.NEXT
enum NextMode {RAND, NEXT, SINGLE}
var is_painting := false
var erase_color : Color = Color.red - Color(0,0,0,0.7)
var precise_erasing := false #TODO

const highlight_color_on = Color.white - Color(0,0,0,0.5)
const highlight_color_off = Color(0,0,0,0)
var spacing = 50 setget set_spacing
var erase_radius : int = 40 setget set_erase_radius

var subnode_name = "decorations"
var custom_name = ""

var custom_scale : float = 0.5 setget set_custom_scale
var rand_scale_mult = 0
var rand_scale : float
var custom_rot : float = 0.0 setget set_custom_rot
var rand_rot_mult = 0
var rand_rot : float

#--- offset
var offset_active = false
var selected_tex_offset_scaled : Vector2

#--- texture collection
var tex_id : int = -1
var tex_full_path := ""
var next_texture : Texture
var tex_collection = []
var tex_collection_selected_ids = []
var tex_collection_path = "res://"

#------------- get nodes ----------------
#--- brush tools
onready var paint_tgg = $tools/paint/activate
onready var paint_color_selector = $tools/paint/color
onready var mode_opt = $tools/paint/opt_mode
onready var spacing_ln = $tools/brush/spac_val
onready var erase_radius_ln = $tools/brush/del_rad
onready var subnode_tgg = $tools/subnode/btn
onready var subnode_ln = $tools/subnode/val
onready var name_tgg = $tools/name/btn 
onready var name_ln = $tools/name/val

#--- settings

#- scale
onready var scale_ln = $settings/scale/val
onready var scale_rand_slider = $settings/scale/rand_sl
onready var scale_rand_ln = $settings/scale/rand_val
#- rotation
onready var rot_ln = $settings/rotation/val
onready var rot_rand_slider = $settings/rotation/rand_sl
onready var rot_rand_ln = $settings/rotation/rand_val


#- folder
onready var folder_btn = $settings/folder/btn
onready var fold_popup = $settings/fold_select

#--- tex grid
onready var tex_selection_button = preload("res://addons/Painter2D/tex_selection_button.tscn")
onready var tex_grid = $tex/grid_cont/grid
onready var offset_tgg = $tex/grid_sets/offset_tgg
onready var btn_select_all = $tex/grid_sets/sel_all
onready var btn_deselect_all = $tex/grid_sets/desel_all

onready var tex_spin_cols = $tex/grid_col/spin_grid
onready var tex_spin_height = $tex/grid_col/spin_grid_height


#--- bottom
onready var info_panel = $infos
onready var disable_plugin_btn = $bott/btn_disable
onready var show_info_btn = $bott/show_info




#================================= INIT ========================================
func _ready():
	connect_everything()
	initialize()

func initialize():
	find_all_textures()
	update_settings()
	update_sprite_grid()
	update_infos()
	check_same_tex_id()


func connect_everything():
	#--- paint tools
	mode_opt.connect("item_selected", self, "mode_selected")
	paint_tgg.connect("toggled",self,"paint_toggled")
	paint_color_selector.connect("color_changed", self, "paint_circle_color_changed")
	erase_radius_ln.connect("text_entered", self, "erase_radius_changed")
	spacing_ln.connect("text_changed", self, "set_spacing")
	
	subnode_tgg.connect("toggled", self, "subnode_ck_toggled")
	subnode_ln.connect("text_changed", self, "subnode_ln_edited")
	name_tgg.connect("toggled",self,"custom_name_toggled")
	name_ln.connect("text_changed",self,"custom_name_changed")
	
	#--- settings
	scale_ln.connect("text_entered",self, "set_custom_scale")
	scale_rand_slider.connect("value_changed", self, "set_rand_scale")
	scale_rand_ln.connect("text_entered", self, "set_rand_scale")
	
	rot_ln.connect("text_entered", self, "set_custom_rot_degrees")
	rot_rand_slider.connect("value_changed", self, "set_rand_rot")
	rot_rand_ln.connect("text_entered", self, "set_rand_rot")
	
	folder_btn.connect("pressed", self, "select_folder_pressed")
	fold_popup.connect("dir_selected", self, "popup_folder_selected")
	
	#--- grid
	tex_spin_cols.connect("value_changed", self, "change_grid_cols")
	tex_spin_height.connect("value_changed", self, "change_grid_height")
	
	offset_tgg.connect("toggled", self, "offset_active_toggled")
	btn_deselect_all.connect("pressed",self, "select_all_tex", [false])
	btn_select_all.connect("pressed",self, "select_all_tex", [true])
	
	#--- fold/unfold buttons
	$btn_sett.connect("pressed",self,"settings_visibility_toggled")
	$btn_tex.connect("pressed",self,"textures_visibility_toggled")
	
	#--- bottom
	disable_plugin_btn.connect("pressed", self, "disable_plugin")
	show_info_btn.connect("pressed", self, "show_hide_infos")


var painter_node_vars = ["spacing", "erase_radius",
"subnode_name", "custom_name",
"custom_scale", "rand_scale_mult",
"custom_rot", "rand_rot_mult",
"tex_collection_selected_ids", "tex_collection_path",
"offset_active"
]
func save_to_painter_node():
	if not painter_node:
		print("DOCK:| save_to_painter_node() -> Painter node not defined.")
		return
	painter_node.is_new = false
	for var_name in painter_node_vars:
		painter_node.set(var_name, get(var_name))
	
	var tex_offset_collection = []
	if tex_grid.get_child_count() > 0:
		for btn in tex_grid.get_children():
			if btn.offset_unit != Vector2.ZERO:
				tex_offset_collection.append([btn.id, btn.offset_unit])
	painter_node.tex_offset_collection = tex_offset_collection


func load_from_painter_node():
#	print("DOCK:| Painter_node selected (%s)"%painter_node.name)
	if painter_node.is_new:
		return
	if not self.is_inside_tree():
		yield(self, "ready")
	for var_name in painter_node_vars:
#		print("%s: %s"%[var_name, painter_node.get(var_name)])
		set(var_name, painter_node.get(var_name))
	
	find_all_textures()
	tex_collection_selected_ids = painter_node.tex_collection_selected_ids
	update_sprite_grid()
	
	var tex_offset_collection = painter_node.tex_offset_collection
	for i in range(tex_offset_collection.size()):
		var btn = tex_grid.get_child(tex_offset_collection[i][0])
		btn.offset_unit = tex_offset_collection[i][1]
	
	update_selection_for_tex_btns()
	
	update_settings()
	update_infos()
	check_same_tex_id()
	print("Painter2D - DOCK:| Settings loaded from painter node (%s)."%painter_node.name)
	

func find_all_textures():
	tex_collection = []
	tex_id = -1
	next_texture = null
	
	var dir = Directory.new()
	dir.open(tex_collection_path)
	dir.list_dir_begin()
	
	while true:
		var file : String = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			if file.get_extension() in ["png", "jpg"]:
				tex_collection.append(file)
	dir.list_dir_end()
	
	if tex_collection.empty():
		print("DOCK: no textures found")
		tex_collection_selected_ids = []
	else:
		tex_collection_selected_ids = range(tex_collection.size())



#=============================== UTILITIES =====================================
func load_tex():
	if tex_collection_selected_ids.empty():
		print("DOCK| Id selection is empty")
		next_texture = null
		return
	
	if not tex_id in tex_collection_selected_ids:
		tex_id = tex_collection_selected_ids[0]
	
	var file_path = tex_collection[tex_id]
	tex_full_path = tex_collection_path + "/" + file_path
	
	if tex_collection_path == "res://":
		tex_full_path = "res://" + file_path
	
	if file_path_is_valid(tex_full_path):
		next_texture = load(tex_full_path)
	else:
		print("DOCK| Filepath is invalid: %s"%tex_full_path)


func file_path_is_valid(path):
	var dir = Directory.new()
	return dir.file_exists(path)


func set_next_texture(val = -1):
	if tex_collection.empty():
		return
	randomize_rand_values()
	
	if val == -1:
		val = mode
	match val:
		NextMode.RAND : select_random_texture()
		NextMode.NEXT : select_next_texture()
		NextMode.SINGLE : check_same_tex_id()


func select_next_texture():
	tex_id += 1
	
	var max_iter = 300
	var iter = 0
	while not tex_id in tex_collection_selected_ids or iter > max_iter:
		iter += 0
		
		tex_id += 1
		if tex_id >= tex_collection.size():
			tex_id = 0
	load_tex()
	set_selected_tex_offset()


func select_random_texture():
	tex_id = tex_collection_selected_ids[randi()%tex_collection_selected_ids.size()]
	load_tex()
	set_selected_tex_offset()


func check_same_tex_id():
	if tex_collection_selected_ids.empty():
		return
	if tex_id in tex_collection_selected_ids:
		return
	else:
		tex_id = tex_collection_selected_ids[0]
		set_selected_tex_offset()


func set_selected_tex_offset(id = tex_id):
	if id == tex_id and tex_grid.get_child_count() > 0:
		selected_tex_offset_scaled = tex_grid.get_child(tex_id).offset_px * (custom_scale - rand_scale)
		update_infos()


func select_all_tex(val):
	if tex_grid.get_child_count() > 0:
		for btn in tex_grid.get_children():
			btn.selected = val
		tex_collection_selected_ids = range(tex_collection.size()) if val else []
		check_same_tex_id()
		update_selection_for_tex_btns()


#============================== UPDATE GUI =====================================
func update_settings():
	paint_tgg.pressed = is_painting
	erase_radius_ln.text = str(erase_radius)
	paint_color_selector.color = erase_color
	mode_opt.selected = mode
	spacing_ln.text = str(spacing)
	
	subnode_ln.text = subnode_name
	subnode_tgg.pressed = subnode_name != ""
	name_ln.text = custom_name
	name_tgg.pressed = custom_name != ""
	
	scale_ln.text = str(custom_scale)
	scale_rand_slider.value = rand_scale_mult
	scale_rand_ln.text = str(rand_scale_mult)
	
	rot_ln.text = str(rad2deg(custom_rot))
	rot_rand_slider.value = range_lerp(rand_rot_mult, 0, 1, 0, 180)
	rot_rand_ln.text = str(rot_rand_slider.value)
	
	folder_btn.text = tex_collection_path
	
	offset_tgg.pressed = offset_active


func update_sprite_grid():
	for child in tex_grid.get_children():
		child.free()
	
	if tex_collection.empty():
		return
	
	for id in range(tex_collection.size()):
		var tex_path = tex_collection[id]
		var btn = tex_selection_button.instance()
		btn.texture = load(tex_collection_path+"/"+tex_path)
		btn.offset_tool_visible = offset_active
		btn.id = id
		btn.dock = self
		btn.connect("selection_changed", self, "btn_selection_changed")
		tex_grid.add_child(btn)
		btn.owner = tex_grid.owner
	change_grid_height(tex_spin_height.value)
	set_next_texture()


func update_infos():
	info_panel.text = \
"""current id: %s
selected ids: %s
mouse pos: %s
offset scaled: %s"""\
%[tex_id, tex_collection_selected_ids, mouse_loc_pos, selected_tex_offset_scaled]
	$tex/infos/curr_id.text = str(tex_id)
	$tex/infos/off_x.text = str(selected_tex_offset_scaled.x)
	$tex/infos/off_y.text = str(selected_tex_offset_scaled.y)


func update_selection_for_tex_btns():
	for btn in tex_grid.get_children():
		btn.selected = btn.id in tex_collection_selected_ids


#=========================== CONNECTED FUNCS ===================================
func paint_toggled(val):
	is_painting = val
	paint_tgg.release_focus()
func mode_selected(val):
	mode = val
func paint_circle_color_changed(col):
	erase_color = col

func set_spacing(val):
	spacing = int(val)
	update_settings()
func erase_radius_changed(val):
	erase_radius = int(val)
	update_settings()
func set_erase_radius(val):
	erase_radius = clamp(val, 5, 1000)
	update_settings()

func set_custom_scale(val):
	val = float(val)
	custom_scale = clamp(val, 0.01, 50)
	update_settings()
func set_rand_scale(val):
	rand_scale_mult = clamp(float(val), 0.0, 1.0)
	randomize_rand_values()
	update_settings()
func set_custom_rot(val):
	custom_rot = val
	update_settings()
func set_custom_rot_degrees(val):
	custom_rot = deg2rad(float(val))
	
func increase_custom_rot(val):
	self.custom_rot += (val)
func set_rand_rot(val):
	rand_rot_mult = range_lerp(float(val), 0, 180, 0, 1)
	print(rand_rot_mult)
	randomize_rand_values()
	update_settings()
func randomize_rand_values():
	randomize()
	rand_scale = rand_range(0, rand_scale_mult)*custom_scale
	rand_rot = rand_range(-rand_rot_mult, rand_rot_mult)*PI


func subnode_ck_toggled(val):
	subnode_name = subnode_ln.text if val else ""
func subnode_ln_edited(text):
	subnode_name = text
	subnode_tgg.pressed = subnode_name != ""
func custom_name_toggled(val):
	custom_name = name_ln.text if val else ""
func custom_name_changed(text):
	custom_name = text
	name_tgg.pressed = custom_name != ""

#- settings
func select_folder_pressed():
	fold_popup.popup()
func popup_folder_selected(path):
	tex_collection_path = path
	folder_btn.text = path
	find_all_textures()
	update_sprite_grid()
	set_next_texture()

#- grid
func btn_selection_changed(id, val):
	if not val:
		if id in tex_collection_selected_ids:
			tex_collection_selected_ids.erase(id)
	else:
		if not id in tex_collection_selected_ids:
			tex_collection_selected_ids.append(id)
	tex_collection_selected_ids.sort()
func offset_active_toggled(val):
	offset_active = val
	for btn in tex_grid.get_children():
		btn.offset_tool_visible = offset_active
func change_grid_cols(val):
	tex_grid.columns = val
	tex_spin_cols.release_focus()
func change_grid_height(val):
	var height : int
	match int(val):
		1: height = 50
		2: height = 70
		3: height = 90
		4: height = 110
		5: height = 140
	for btn in tex_grid.get_children():
		btn.get_node("btn").rect_min_size.y = height

#- bottom
func disable_plugin():
	var dummy = EditorPlugin.new()
	dummy.get_editor_interface().set_plugin_enabled("Painter2D", false)
	dummy.queue_free()
func show_hide_infos():
	info_panel.visible = !info_panel.visible



#---- fold / unfold
func textures_visibility_toggled():
	$tex.visible = !$tex.visible
func settings_visibility_toggled():
	$settings.visible = !$settings.visible


func highlight_spacing(val):
	var col = highlight_color_on if val else highlight_color_off
	$tools/brush/lb_spac.set("custom_colors/font_color_shadow", col)
func highlight_erase(val):
	var col = highlight_color_on if val else highlight_color_off
	$tools/brush/lb_delete.set("custom_colors/font_color_shadow", col)
func highlight_scale(val):
	var col = highlight_color_on if val else highlight_color_off
	$settings/scale/lb.set("custom_colors/font_color_shadow", col)
func highlight_rotation(val):
	var col = highlight_color_on if val else highlight_color_off
	$settings/rotation/lb.set("custom_colors/font_color_shadow", col)



