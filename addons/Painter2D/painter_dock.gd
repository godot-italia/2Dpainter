#===============================#
#       painter_dock.gd         #
#===============================#

tool
extends VBoxContainer

var mode = NextMode.NEXT
var is_painting := false
var paint_color : Color = Color.red - Color(0,0,0,0.7)
var spacing = 50 setget set_spacing
var paint_radius : int = 40 setget set_paint_radius

var custom_scale : float = 0.5 setget set_custom_scale
enum NextMode {RAND, NEXT, SINGLE}

#--- offset
var offset_active = false
var selected_tex_offset_scaled : Vector2

#--- texture collection
var tex_id : int = -1
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


#--- settings
onready var ck_offset = $grid_col/ck_offset


#- scattering


#- scale
onready var scale_val = $settings/scale/val
onready var scale_rand_slider = $settings/scale/rand_sl
onready var scale_rand_val = $settings/scale/rand_val

#- rotation

#- selection
onready var tex_grid = $textures/grid
onready var folder_btn = $settings/folder/btn
onready var tex_selection_button = preload("res://addons/Painter2D/tex_selection_button.tscn")




#================================= INIT ========================================
func _ready():
	connect_everything()
	find_all_textures()
	set_next_texture()
	update_dock()


func connect_everything():
	#paint
	scatter_paint_tgg.connect("toggled",self,"scatter_paint_toggled")
	scatter_paint_color.connect("color_changed", self, "paint_circle_color_changed")
	paint_rad_slider.connect("value_changed", self, "paint_radius_changed")
	paint_rad_le.connect("text_entered", self, "paint_radius_changed")
	mode_opt.connect("item_selected", self, "mode_selected")
	
	
	#settings
	disable_plugin_btn.connect("toggled", self, "enable_plugin")
	show_info_btn.connect("pressed", self, "show_hide_infos")
	
	ck_offset.connect("toggled", self, "offset_active_toggled")
	$grid_col/spin_grid.connect("value_changed", self, "change_grid_cols")
	$grid_col/spin_grid_height.connect("value_changed", self, "change_grid_height")
	
	folder_btn.connect("pressed", self, "select_folder_pressed")
	$settings/fold_select.connect("dir_selected", self, "popup_folder_selected")


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
	
	tex_collection_selected_ids = []
	for i in range(tex_collection.size()):
		tex_collection_selected_ids.append(i)


#=============================== UTILITIES =====================================
func set_next_texture():
	match mode:
		NextMode.RAND : next_texture = select_random_texture()
		NextMode.NEXT : next_texture = select_next_texture()
		NextMode.SINGLE : return


func select_next_texture():
	tex_id += 1
	if tex_collection_selected_ids.empty():
		tex_collection_selected_ids.append(0)
	
	var max_iter = 300
	var iter = 0
	while not tex_id in tex_collection_selected_ids or iter > max_iter:
		iter += 0
		
		tex_id += 1
		if tex_id >= tex_collection.size():
			tex_id = 0
	var file_path = tex_collection[tex_id]
	next_texture = load(tex_collection_path + "/" + file_path)
	update_selected_tex_offset(tex_id)
#	return next_texture


func select_random_texture():
	tex_id = tex_collection_selected_ids[randi()%tex_collection_selected_ids.size()]
	var file_path = tex_collection[tex_id]
	next_texture = load(tex_collection_path + "/" + file_path)
#	return next_texture


func update_selected_tex_offset(id):
	if id == tex_id:
		selected_tex_offset_scaled = tex_grid.get_child(tex_id).offset_px * custom_scale

#============================== UPDATE GUI =====================================
func update_dock():
	update_settings()
	update_sprite_grid()
	#--- deactivate plugin (DEBUG)
	var dummy = EditorPlugin.new()
	disable_plugin_btn.pressed = dummy.get_editor_interface().is_plugin_enabled("Painter2D")
	dummy.queue_free()


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
	change_grid_height($grid_col/spin_grid_height.value)
	set_next_texture()


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

func enable_plugin(val):
	var dummy = EditorPlugin.new()
	dummy.get_editor_interface().set_plugin_enabled("Painter2D", val)
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
	print("Selection ids: %s"%[tex_collection_selected_ids])


func offset_active_toggled(val):
	offset_active = val
	for btn in tex_grid.get_children():
		btn.offset_tool_visible = offset_active
func change_grid_cols(val):
	tex_grid.columns = val
	$grid_col/spin_grid.release_focus()
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
	select_next_texture()
	find_all_textures()
	yield(get_tree(), "idle_frame")
	update_sprite_grid()



