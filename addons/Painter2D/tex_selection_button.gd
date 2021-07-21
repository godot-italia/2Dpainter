tool
extends GridContainer

var dock

var id : int = 0
var texture : Texture
var tex_file : String
var tex_folder : String
var offset_unit : Vector2 = Vector2.ZERO
var offset_px : Vector2 = Vector2.ZERO
var offset_tool_visible := true setget set_offset_tool_visible
var selected := true setget set_selected

signal selection_changed


func _ready():
	$btn.connect("item_rect_changed", self, "button_resized")
	$vsl.connect("value_changed", self, "voffset_changed")
	$hsl.connect("value_changed", self, "hoffset_changed")
	$btn.connect("toggled", self, "btn_toggled")
	$btn_reset.connect("pressed", self, "reset_offset")
	$btn/tex.texture = texture
	update_gui()


func button_resized():
	move_cross()


func move_cross():
	if not $btn/tex.texture:
		return
	var i = $btn/tex.texture.get_size()
	var b = $btn.rect_size
	var i1 : Vector2
	

	if i.x < i.y:
		i1.y = b.y
		i1.x = i.x * (i1.y / i.y)
	else:
		i1.x = b.x
		i1.y = i.y * (i1.x / i.x)
	
	var btn_cent = b/2
	var scaled_offset : Vector2
	scaled_offset.x = (i1.x * offset_unit.x) / 2
	scaled_offset.y = (i1.y * offset_unit.y) / 2
	
	var cross_center = btn_cent + scaled_offset
	$btn/tex/cross.position = cross_center
#	if get_position_in_parent() == 0:
#		print("============================")
#		print("i: %s"%i)
#		print("b: %s"%b)
#		print("i1: %s"%i1)
#		print("scaled_offset: %s"%scaled_offset)
#		print("btn_cent: %s"%btn_cent)
#		print("cross_center: %s"%cross_center)


func voffset_changed(val):
	offset_unit.y = val
	update_offset_px()
	move_cross()
func hoffset_changed(val):
	offset_unit.x = val
	update_offset_px()
	move_cross()
func update_offset_px():
	offset_px.x = (texture.get_size().x * offset_unit.x)/2
	offset_px.y = (texture.get_size().y * offset_unit.y)/2
	dock.set_selected_tex_offset(id)

func btn_toggled(val):
	self.selected = val
	$btn.release_focus()
	emit_signal("selection_changed", id, val)

func set_selected(val):
	selected = val
	$btn.pressed = val
	$btn/bg.visible = val


func set_offset_tool_visible(val):
	offset_tool_visible = val
	update_gui()

func update_gui():
	$btn/bg.visible = selected
	$btn.pressed = selected
	$btn/id.text = str(id)
	
	columns = 2 if offset_tool_visible else 1
	$btn/tex/cross.visible = offset_tool_visible
	$vsl.visible = offset_tool_visible
	$hsl.visible = offset_tool_visible
	$btn_reset.visible = offset_tool_visible
	move_cross()

func reset_offset():
	offset_unit = Vector2.ZERO
	update_offset_px()
	$vsl.value = 0
	$hsl.value = 0
	update_gui()


