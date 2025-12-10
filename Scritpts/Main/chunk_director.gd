# ステージ生成スクリプト
# _process() (毎フレーム実行されるメソッド) でステージ生成
extends Node
var initial_generate_obs_offset = 0

@onready var main = get_node("/root/Main")
@export var player: CharacterBody3D
# ▼ 各モードで使用するチャンクを格納する配列
@export var easy_chunks: Array[ChunkData]
@export var medium_chunks: Array[ChunkData] 
@export var hard_chunks: Array[ChunkData]   
# ▼ ステージを構成するパーツ
@export var floor_scene: PackedScene # 床や道路のシーン
var obstacle_scenes := {
	"jump": preload("res://Scenes/Obstacles/bar_horizontal.tscn"),
	"wall": preload("res://Scenes/Obstacles/wall.tscn"),
	"slide": preload("res://Scenes/Obstacles/bar_horizontal.tscn")
}

# ▼ 生成ロジックの設定
@export var spawn_ahead_distance := 60.0 # プレイヤーの何m先のチャンクを生成するか
@export var despawn_behind_distance := 20.0 # プレイヤーの何m後ろのチャンクを削除するか
@export var spawn_space := -50	# playerが召喚されたあとのスペース

@export var play_area_width: float = 21.0
@export var lane_width: float = 7.0

# --- 内部で使う変数 ---
var active_chunk_nodes: Array[Node3D] = [] # 配置済みのチャンク（親ノード）を管理
var next_chunk_z_pos: float = 0.0 # 次にチャンクを配置するZ座標
var is_ready_to_spawn := false # カメラの準備ができるまでfalse

# ステージ全体の設計図となる配列
var master_chunk_list: Array[ChunkData] = []
# 次に生成すべきチャンクのインデックス
var current_chunk_index: int = 0
var easy_section_end_index: int = 0
var medium_section_end_index: int = 0
var hard_section_end_index: int = 0
# Main.gdが参照するための、計算後のリスタート地点のZ座標
var start_z_pos: float = 0.0

func _ready() -> void:
	player.speed = 16
	# 各セクションの終了インデックスを計算
	easy_section_end_index = easy_chunks.size()
	medium_section_end_index = easy_chunks.size() + medium_chunks.size()
	# ▼▼▼ ここでマスターリストを作成 ▼▼▼
	# 各難易度のチャンク配列を順番に結合する
	master_chunk_list.append_array(easy_chunks)
	master_chunk_list.append_array(medium_chunks)
	master_chunk_list.append_array(hard_chunks)

	 # Settingsから開始セクションを読み取る
	match Settings.start_section:
		Settings.Difficulty.EASY:
			# 何もせず、最初からスタート
			player.speed = 18.0
			current_chunk_index = 0
			next_chunk_z_pos = 0.0
			AudioManager.set_bgm_pitch(1.0)
		
		Settings.Difficulty.MEDIUM:
			print("Mediumセクションからリスタートします。")
			player.speed = 22.0
			current_chunk_index = easy_section_end_index
			# Easyセクションのチャンクをスキップし、その分の長さを計算
			next_chunk_z_pos = calculate_skipped_length(easy_section_end_index)
			AudioManager.set_bgm_pitch(1.15)

		Settings.Difficulty.HARD:
			print("Hardセクションからリスタートします。")
			player.speed = 25.0
			current_chunk_index = medium_section_end_index
			# EasyとMediumセクションをスキップ
			next_chunk_z_pos = calculate_skipped_length(medium_section_end_index)
			AudioManager.set_bgm_pitch(1.3)
	# 計算した開始位置を、Mainが後で使えるように保存しておく
	self.start_z_pos = next_chunk_z_pos
			
	# ゲーム開始時はまず障害物のない床だけを生成しておく
	spawn_initial_floor(next_chunk_z_pos)

# スキップされたチャンクの合計長を計算するヘルパー関数
func calculate_skipped_length(end_index: int) -> float:
	var skipped_length: float = 0.0
	for i in range(end_index):
		skipped_length += master_chunk_list[i].length
	return skipped_length

# 起動時に最初の平坦な床をいくつか生成する関数
func spawn_initial_floor(start_pos: float):
	var initial_floor_block_length = spawn_space + spawn_ahead_distance # + initial_generate_obs_offset # 最初の床の長さ
	var chunk_parent = Node3D.new()
	# 引数で受け取った start_pos をチャンクの親ノードのZ座標に設定
	chunk_parent.position.z = start_pos
	print("chunk_z_pos", chunk_parent.position.z)
	print("player_z_pos", player.position.z)
	add_child(chunk_parent)

	var floor_block = floor_scene.instantiate()
	chunk_parent.add_child(floor_block)

	# 床のサイズと位置を調整 (以前のコードと同様)
	var floor_block_mesh = floor_block.get_node("StaticBody3D/MeshInstance3D")
	var collision = floor_block.get_node("StaticBody3D/CollisionShape3D")
	if floor_block_mesh and collision:
		floor_block_mesh.mesh = floor_block_mesh.mesh.duplicate()
		collision.shape = collision.shape.duplicate()
		floor_block_mesh.mesh.size.z = initial_floor_block_length
		collision.shape.size.z = initial_floor_block_length
		var offset = initial_floor_block_length / 2.0
		floor_block_mesh.position.z = offset
		collision.position.z = offset
	
	chunk_parent.set_meta("length", initial_floor_block_length)
	active_chunk_nodes.append(chunk_parent)
	# next_chunk_z_posの更新も、start_posを基準にする
	next_chunk_z_pos = start_pos + initial_floor_block_length


func _process(_delta):
	if main.is_game_over :	# or main.is_game_started
		return

	if not is_ready_to_spawn:
		return

	if player.global_position.z + spawn_ahead_distance > next_chunk_z_pos:
		spawn_new_chunk()

	# プレイヤーの後ろにある古いチャンクを削除
	if not active_chunk_nodes.is_empty():
		var first_chunk = active_chunk_nodes[0]
		# チャンクの終端がプレイヤーより一定距離後ろになったら削除
		if first_chunk.position.z + (first_chunk.get_meta("length", 0)) < player.global_position.z - despawn_behind_distance:
			active_chunk_nodes.pop_front()
			first_chunk.queue_free()

# Main.gdから呼び出される、生成開始の合図
func start_spawning():
	print("ChunkDirector: 障害物生成を開始します。")
	is_ready_to_spawn = true

func spawn_new_chunk():

	# 全てのチャンクを生成し終えたら、何もしない
	if current_chunk_index >= master_chunk_list.size():
		# ここでゲームクリアの処理などを呼び出しても良い
		if not main.is_game_cleared:
			await get_tree().create_timer(2.0).timeout
			print("全てのチャンクを生成しました。ステージクリア！")
			main.trigger_game_clear()
		return

	# マスターリストから順番にチャンクデータを取得
	var selected_chunk_data: ChunkData = master_chunk_list[current_chunk_index]

	# ▼▼▼ 進行状況をSettingsに保存. モード切替 ▼▼▼
	if current_chunk_index == easy_section_end_index + 1: # > にしたいが、それではダメ。+1が丁度クリアしたところを指す
		player.speed = 20.0
		Settings.start_section = Settings.Difficulty.MEDIUM
		print("チェックポイントをMediumに更新しました。")
		main.update_mode_display(Settings.Difficulty.MEDIUM) #, player.speed)
		AudioManager.set_bgm_pitch(1.15)
		
	elif current_chunk_index == medium_section_end_index + 1:
		player.speed = 24.0
		Settings.start_section = Settings.Difficulty.HARD
		print("チェックポイントをHardに更新しました。")
		main.update_mode_display(Settings.Difficulty.HARD) #, player.speed)
		AudioManager.set_bgm_pitch(1.3)
		# main.setBGMPitchFromDifficulty()
	current_chunk_index += 1

	# 1. チャンク全体をまとめる親ノードを作成
	var chunk_parent = Node3D.new()
	chunk_parent.position.z = next_chunk_z_pos
	add_child(chunk_parent)
	
	# チャンクの長さをメタデータとして保存（削除時に利用）
	chunk_parent.set_meta("length", selected_chunk_data.length)

	# 2. 床を生成して親ノードの子にする
	var floor_block = floor_scene.instantiate()
	chunk_parent.add_child(floor_block)

	# --- ここで長さを反映 ---
	var length = float(selected_chunk_data.length) # 浮動小数点数として扱う
	# 操作するノードを取得
	var floor_mesh_instance = floor_block.get_node("StaticBody3D/MeshInstance3D")
	var collision = floor_block.get_node("StaticBody3D/CollisionShape3D")

	if floor_mesh_instance and collision and floor_mesh_instance.mesh is BoxMesh and collision.shape is BoxShape3D:
		# (重要) リソースを複製して、他のインスタンスに影響が出ないようにする
		floor_mesh_instance.mesh = floor_mesh_instance.mesh.duplicate()
		collision.shape = collision.shape.duplicate()
		
		# 手順1: サイズを変更
		floor_mesh_instance.mesh.size.z = length
		collision.shape.size.z = length

		# 手順2: 中心のズレを補正するために、ローカル位置を前方に移動
		var offset_z = length / 2.0
		floor_mesh_instance.position.z = offset_z
		collision.position.z = offset_z

	# ----------------------
	if selected_chunk_data.obstacles.size() > 0:

		# 3. 障害物を配置して親ノードの子にする
		var obs = selected_chunk_data.obstacles
		var zlist = selected_chunk_data.z_pos_list
		var floatlist = selected_chunk_data.float_amount_list

		for i in obs.size():
			var obstacle_data = obs[i]
			var z_pos_in_chunk = zlist[i] if zlist.size() > i else 0
			var float_amount = floatlist[i] if floatlist.size() > i else 0.0

			var type = obstacle_data.type
			var lane = obstacle_data.lane

			if not obstacle_scenes.has(type):
				push_warning("obstacle_scenesに型 '%s' が見つかりません" % type)
				continue

			var obstacle_scene = obstacle_scenes[type]
			var new_obstacle = obstacle_scene.instantiate()

			# MeshInstance3Dの高さを取得
			var obstacle_height = 1.0
			obstacle_height = new_obstacle.get_obstacle_height()

			# 床の高さ（例: 1m）を取得
			var floor_height = 1.0
			var floor_mesh = floor_block.get_node("StaticBody3D/MeshInstance3D")
			if floor_mesh and floor_mesh.mesh is BoxMesh:
				floor_height = floor_mesh.mesh.size.y

			new_obstacle.position = calc_obstacle_position(
				lane, z_pos_in_chunk, obstacle_height, float_amount, floor_height
			)
			chunk_parent.add_child(new_obstacle)
	else:
		pass	# 障害物が空のときは床だけ生成
	
	# 4. 管理リストに追加し、次のZ座標を更新
	active_chunk_nodes.append(chunk_parent)
	next_chunk_z_pos += selected_chunk_data.length

# レーン番号とZ位置から、3D空間上のX,Z座標を計算する
func calc_obstacle_position(
	lane: int,
	z_pos: float,
	obstacle_height: float,
	float_amount: float,
	floor_height: float
) -> Vector3:
	var x_pos = (1 - lane) * lane_width
	# 床の上面 + 障害物の半分 + 浮かせ量
	var y_pos = floor_height / 2.0 + obstacle_height / 2.0 + float_amount
	return Vector3(x_pos, y_pos, z_pos)

	
