# 各Obstacleのサイズとコライダーのサイズを初期化するスクリプト

extends Node3D
# 子シーンでサイズ変更できるようにインスペクターで表示しておく
@export var shape_size: Vector3 = Vector3(1, 1, 1)  # デフォルトサイズ

func _ready():
	# duplicate しないと継承元にも影響がある
	var new_shape = $StaticBody3D/CollisionShape3D.shape.duplicate()
	new_shape.extents = shape_size / 2
	$StaticBody3D/CollisionShape3D.shape = new_shape

	var new_mesh = $StaticBody3D/MeshInstance3D.mesh.duplicate()
	new_mesh.size = shape_size
	$StaticBody3D/MeshInstance3D.mesh = new_mesh

	var front_hitbox = $FrontHitbox
	var z_offset = shape_size.z / 2 + 0.01	# 少し前に配置
	front_hitbox.transform.origin.z = -z_offset	# プレイヤーが進んでくる側

	# FrontHitboxのコリジョンサイズを調整
	var front_shape = front_hitbox.get_node("CollisionShape3D").shape.duplicate()
	if front_shape is BoxShape3D:
		front_shape.extents = Vector3(
			shape_size.x / 2,
			shape_size.y / 2+0.01,	# 頭が引っかかって動かなくなることがあるから、少し伸ばしておく
			0.015  # 非常に薄くする（前面だけで当たり判定）
		)
		front_hitbox.get_node("CollisionShape3D").shape = front_shape

# chunk_director.gd で呼び出す
func get_obstacle_height() -> float:
	return shape_size.y
