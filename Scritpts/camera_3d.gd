extends Camera3D

@export var target_path: NodePath
var target: Node3D

func _ready():
	target = get_node(target_path)
	

func _process(_delta):
	if target:
		var target_pos = target.global_transform.origin
		global_transform.origin = target_pos + Vector3(0, 5, -8)	# 通常
		# global_transform.origin = target_pos + Vector3(0, 60, -40)	# デバッグ用　俯瞰 前方確認
		# global_transform.origin = target_pos + Vector3(0, 60, 40)	# デバッグ用　俯瞰 後方確認
		look_at(target_pos, Vector3.UP)
