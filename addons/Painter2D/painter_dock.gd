#===============================#
#       painter_dock.gd         #
#===============================#

tool
extends VBoxContainer

var mouse_loc_pos
var view_transform

var mode = NextMode.NEXT
var is_painting := false
var paint_color : Color = Color.red - Color(0,0,0,0.7)
var spacing = 50 setget set_spacing
var paint_radius : int = 40 setget set_paint_radius
var subnode_name = ""

var custom_scale : float = 0.5 setget set_custom_scale
enum NextMode {RAND, NEXT, SINGLE}

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
onready var info_panel = $infos
onready var disable_plugin_btn = $bott/btn_disable
onready var show_info_btn = $bott/show_info

#--- brush
onready var mode_opt = $tools/scatter_paint/opt_mode
onready var spacing_val = $tools/radius/spacing
onready var scatter_paint_tgg = $tools/scatter_paint/activate
onready var scatter_paint_color = $tools/scatter_paint/color
onready var paint_rad_slider = $tools/radius/slider
onready var paint_rad_le = $tools/radius/val
onready var subnode_ck = $tools/subnode/btn
onready var subnode_ln = $tools/subnode/val

#--- settings
onready var ck_offset = $tex/grid_sets/ck_offset
onready var folder_btn = $settings/folder/btn


#- scattering


#- scale
onready var scale_val = $settings/scale/val
onready var scale_rand_slider = $settings/scale/rand_sl
onready var scale_rand_val = $settings/scale/rand_val

#- rotation

#- selection
onready var tex_selection_button = preload("res://addons/Painter2D/tex_selection_button.tscn")
onready var tex_grid = $tex/grid_cont/grid
onready var tex_spin_cols = $tex/grid_col/spin_grid
onready var tex_spin_height = $tex/grid_col/spin_grid_height




#================================= INIT ========================================
func _ready():
	connect_everything()
	find_all_textures()
	select_next_texture()
	update_settings()
	update_sprite_grid()
	update_infos()


func connect_everything():
	#paint
	scatter_paint_tgg.connect("toggled",self,"scatter_paint_toggled")
	scatter_paint_color.connect("color_changed", self, "paint_circle_color_changed")
	paint_rad_slider.connect("value_changed", self, "paint_radius_changed")
	paint_rad_le.connect("text_entered", self, "paint_radius_changed")
	mode_opt.connect("item_selected", self, "mode_selected")
	
	subnode_ck.connect("toggled", self, "subnode_ck_toggled")
	subnode_ln.connect("text_entered", self, "subnode_ln_edited")
	
	
	#settings
	disable_plugin_btn.connect("pressed", self, "disable_plugin")
	show_info_btn.connect("pressed", self, "show_hide_infos")
	
	ck_offset.connect("toggled", self, "offset_active_toggled")
	tex_spin_cols.connect("value_changed", self, "change_grid_cols")
	tex_spin_height.connect("value_changed", self, "change_grid_height")
	
	folder_btn.connect("pressed", self, "select_folder_pressed")
	$settings/fold_select.connect("dir_selected", self, "popup_folder_selected")
	
	#- select/deselect all
	$tex/grid_sets/desel_all.connect("pressed",self, "select_all_tex", [false])
	$tex/grid_sets/sel_all.connect("pressed",self, "select_all_tex", [true])
	#- fold/unfold buttons
	$btn_sett.connect("pressed",self,"settings_visibility_toggled")
	$btn_tex.connect("pressed",self,"textures_visibility_toggled")


func find_all_textures():
	tex_collection = []
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
	
	tex_collection_selected_ids = range(tex_collection.size())



#=============================== UTILITIES =====================================
func load_tex():
	if tex_id == -1:
		tex_id = tex_collection_selected_ids[0]
	
	if tex_collection_selected_ids.empty():
		tex_collection_selected_ids.append(0)
	
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


func set_next_texture(val = 1):
	match mode:
		NextMode.RAND : select_random_texture()
		NextMode.NEXT : select_next_texture()
		NextMode.SINGLE : return


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
	set_selected_tex_offset(tex_id)


func select_random_texture():
	tex_id = tex_collection_selected_ids[randi()%tex_collection_selected_ids.size()]
	load_tex()
	set_selected_tex_offset(tex_id)


func set_selected_tex_offset(id):
	if id == tex_id and tex_grid.get_child_count() > 0:
		selected_tex_offset_scaled = tex_grid.get_child(tex_id).offset_px * custom_scale
		update_infos()


func select_all_tex(val):
	if tex_grid.get_child_count() > 0:
		for btn in tex_grid.get_children():
			btn.selected = val
		tex_collection_selected_ids = range(tex_collection.size()) if val else [0]
#		update_selection_for_tex_btns()


#============================== UPDATE GUI =====================================
func update_settings():
	paint_rad_slider.value = paint_radius
	paint_rad_le.text = str(paint_radius)
	paint_rad_slider.release_focus()
	paint_rad_le.release_focus()
	scatter_paint_color.color = paint_color
	ck_offset.pressed = offset_active
	folder_btn.text = tex_collection_path
	mode_opt.selected = mode
	
	scale_val.text = str(custom_scale)
	spacing_val.text = str(spacing)


func update_sprite_grid():
	for child in tex_grid.get_children():
		child.free()
	
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
	$infos.text = \
"""current id: %s
selected ids: %s
mouse pos: %s
offset scaled: %s"""\
%[tex_id, tex_collection_selected_ids, mouse_loc_pos, selected_tex_offset_scaled]


func update_selection_for_tex_btns():
	for btn in $textures/grid.get_children():
		btn.selected = btn.id in tex_collection_selected_ids


#=========================== CONNECTED FUNCS ===================================
func scatter_paint_toggled(val):
	is_painting = val
	scatter_paint_tgg.release_focus()
func paint_circle_color_changed(col):
	paint_color = col
func paint_radius_changed(val):
	paint_radius = int(val)
	update_settings()
func set_paint_radius(val):
	paint_radius = clamp(val, 5, 150)
	update_settings()
func set_custom_scale(val):
	custom_scale = clamp(val, 0.01, 50)
	update_settings()

func disable_plugin():
	var dummy = EditorPlugin.new()
	dummy.get_editor_interface().set_plugin_enabled("Painter2D", false)
	dummy.queue_free()

func set_spacing(val):
	spacing = val
	update_settings()

func mode_selected(val):
	mode = val

func btn_selection_changed(id, val):
	if not val:
		if id in tex_collection_selected_ids:
			tex_collection_selected_ids.erase(id)
	else:
		if not id in tex_collection_selected_ids:
			tex_collection_selected_ids.append(id)
	tex_collection_selected_ids.sort()
#	print("Selection ids: %s"%[tex_collection_selected_ids])


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
	
	
func show_hide_infos():
	$infos.visible = !$infos.visible

func select_folder_pressed():
	$settings/fold_select.popup()
func popup_folder_selected(path):
	tex_collection_path = path
	folder_btn.text = path
	find_all_textures()
	update_sprite_grid()
	set_next_texture()
#	yield(get_tree(), "idle_frame")

func subnode_ck_toggled(val):
	subnode_name = subnode_ln.text if val else ""

func subnode_ln_edited(text):
	subnode_name = text
	if subnode_name == "":
		subnode_ck.pressed = false

#---- fold / unfold
func textures_visibility_toggled():
	$tex.visible = !$tex.visible
func settings_visibility_toggled():
	$settings.visible = !$settings.visible


