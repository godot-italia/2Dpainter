tool
extends Node2D
class_name Painter2D, "res://addons/Painter2D/graphics/painter2d_ico.png"


export var spacing : int = 50
export var erase_radius : int = 50

export var subnode_name : String = ""
export var custom_name : String = ""

export var custom_scale : float = 1.0
export var rand_scale_mult : int = 0
export var custom_rot : float = 0
export var rand_rot_mult : int = 0


#--- offset
export var offset_active : bool = false

#--- texture collection
export var tex_collection_selected_ids : Array = []
export var tex_collection_path : String = "res://"

export var tex_offset_collection : Array = []

func _ready():
	scale = Vector2.ONE
	global_position = Vector2.ZERO
