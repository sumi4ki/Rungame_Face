extends CharacterBody3D

signal collided

var current_control_mode = "face" # または "keyboard"
@export var speed = 16	# easy:13, medium: difficult:19
@export var speed_slide = 20
@export var jump_velocity = 30
@export var jump_height := 5.0
@export var jump_gravity_up := 65.0
@export var jump_gravity_down := 80.0
@export var gravity_magnitude = 9.8 * 5.0
# スライディング中に顔が上に動いた量を累積する
var upward_face_movement_while_sliding: float = 0.0
@export var slide_exit_threshold: float = 0.2
@onready var sliding_timer = $SlidingTimer
@onready var collider = $CollisionShape3D
@onready var main = get_node("/root/Main")
@onready var chunk_director = get_node("/root/Main/ChunkDirector")
@onready var jump_sound = $SoundEffects/JumpSound
@onready var sliding_sound = $SoundEffects/SlidingSound
@onready var footsteps_sound = $SoundEffects/FootstepsSound
@onready var collision_sound = $SoundEffects/CollisionSound
# websocket 用
var face_x := 0.5  # 中央
var face_y := 0.5

var is_sliding = false
var default_shape
var sliding_shape

# --- 顔の移動速度判定用 ---
var previous_face_y := 0.5
@export var face_move_sensitivity := 0.7 # 例: 0.7なら顔の中心から±0.35で床の端まで移動

func _ready():
	# Autoloadのシグナルに接続
	WebSocketManager.message_received.connect(_on_web_socket_receive_message_received)
	# 初期の当たり判定を保存（例：カプセル）
	default_shape = collider.shape.duplicate()
	sliding_shape = CapsuleShape3D.new()
	sliding_shape.radius = default_shape.radius
	sliding_shape.height = default_shape.height * 0.4

func _physics_process(delta):
	if Engine.time_scale == 0.0:
		return
	if main.is_game_over:
		return 
	velocity.z = speed  # 奥方向に常に進む

	var target_x: float

	# プレイヤーが移動できるX座標の範囲を計算（コースアウトしないように）
	var floor_width = chunk_director.play_area_width # プレイエリアの幅を使用
	var player_width = 1.0 # プレイヤーの当たり判定の幅（実際の値に調整してください）
	var move_range = (floor_width - player_width) / 2.0

	if current_control_mode == "face":
		# 顔移動ロジック
		# 感度を考慮した範囲に変換
		var center = 0.5
		var face_move_sensitivityrange = face_move_sensitivity / 2.0
		var min_face = center - face_move_sensitivityrange
		var max_face = center + face_move_sensitivityrange
		var clamped_face_x = clamp(face_x, min_face, max_face)
		# 0.0～1.0の範囲を感度範囲内で再正規化
		var normalized = (clamped_face_x - min_face) / (max_face - min_face)
		target_x = lerp(-move_range, move_range, normalized)
		var desired_velocity_x = (target_x - global_transform.origin.x) * speed_slide
		velocity.x = desired_velocity_x

	elif current_control_mode == "keyboard":
		# キーボード移動ロジック
		var input_dir = Vector3.ZERO
		if Input.is_action_pressed("move_left"):
			input_dir.x -= 1
		if Input.is_action_pressed("move_right"):
			input_dir.x += 1
		# ワールド座標系での移動に変換
		var direction = global_transform.basis * input_dir
		velocity.x = direction.x * speed_slide
		# ここで位置を直接クランプする（もしCharacterBody2D/3Dを使わずpositionを直接変更する場合）
		# これは、move_and_slide()の挙動を無視するから、エラーが起きるかも
		global_transform.origin.x = clamp(global_transform.origin.x, -move_range, move_range)
		# または、CharacterBody2D/3Dのmove_and_slide()で壁にぶつかるようにする

	# --- ここからジャンプ・スライディングのロジック ---

	# 1. 接地しているかチェック
	var is_grounded = is_on_floor()

	# 2. 重力を適用
	if not is_grounded:
		var gravity = 0.0
		if velocity.y > 0:
			gravity = jump_gravity_up
		else:
			gravity = jump_gravity_down
		velocity.y -= gravity * delta

	# 3. ジャンプ・スライディングの入力
	if is_grounded:
		if current_control_mode == "keyboard":
			if Input.is_action_just_pressed("move_up"):
				Jump()
			if Input.is_action_just_pressed("move_down") and !is_sliding:
				start_sliding()
		elif current_control_mode == "face":
			var diff = face_y - previous_face_y
			# ワープチェック：もし1フレームで顔が画面の10%以上 (0.1) 動いたらスキップ
			if abs(diff) > 0.1: 
					previous_face_y = face_y # 現在の値に同期
			else:
				# 顔の移動速度による判定
				var face_y_velocity = diff / delta

				if face_y_velocity < -Settings.jump_velocity_threshold:
						Jump()
				elif face_y_velocity > Settings.sliding_velocity_threshold and !is_sliding:
						start_sliding()

	previous_face_y = face_y

	move_and_slide()

	# --- スライディング終了判定（ホールドモード用） ---
	if is_sliding and Settings.current_slide_mode == Settings.SlideMode.HOLD:
		# 現在のフレームでの顔の上下移動量を計算
		var face_y_delta = face_y - previous_face_y

		# 顔が上に動いた場合 (face_yが小さくなった場合)
		if face_y_delta < 0:
			# 移動量を正の値にして累積
			upward_face_movement_while_sliding += -face_y_delta

		# 累積値がしきい値を超えたらスライディング終了
		if upward_face_movement_while_sliding > slide_exit_threshold:
			stop_sliding()

func play_footstep():
	# 走っている時だけ鳴らす
	if is_on_floor():
		footsteps_sound.pitch_scale = randf_range(0.8, 1.2)
		footsteps_sound.play()

func start_sliding():
	print("slidig start")
	sliding_sound.play()
	$AnimationPlayer.play("slide")
	is_sliding = true

	# ▼▼▼ モードに応じて処理を分岐 ▼▼▼
	if Settings.current_slide_mode == Settings.SlideMode.TIMER:
		sliding_timer.start()
	elif Settings.current_slide_mode == Settings.SlideMode.HOLD:
		# ホールドモードの場合、移動量の累積をリセットして記録開始
		upward_face_movement_while_sliding = 0.0

# ▼▼▼ スライディングを終了する共通関数を作成 ▼▼▼
func stop_sliding():
	sliding_sound.stop()
	is_sliding = false
	# アニメーション終了時にrunに戻るロジックが既にあるので、
	# is_sliding を false にするだけ

func Jump():
	velocity.y = jump_velocity
	# SE
	sliding_sound.stop()
	jump_sound.pitch_scale = randf_range(0.9, 1.1)
	jump_sound.play()
	# Animation
	$AnimationPlayer.play("jump")

func _on_sliding_timer_timeout() -> void:
	stop_sliding()

func dead():
	emit_signal("collided")
	# Playerが生きている時になっていたSEを止める
	get_tree().call_group("PlayerAliveSEGroup", "stop")
	collision_sound.play()
	main.trigger_game_over()
	print("player has collided")

func _unhandled_input(event):
	if event.is_action_pressed("toggle_control_mode"): # 例: 'M' キーをこのアクションに割り当てる
		if current_control_mode == "face":
			current_control_mode = "keyboard"
			print("Control Mode: Keyboard")
		else:
			current_control_mode = "face"
			print("Control Mode: Face")

func _on_web_socket_receive_message_received(data: Dictionary) -> void:
	if  data.has("face_x"):
		var face_x_val = clamp(float(data["face_x"]), 0.0, 1.0)
		face_x = face_x_val
	if  data.has("face_y"):
		var face_y_val = clamp(float(data["face_y"]), 0.0, 1.0)
		face_y = face_y_val

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	# pass
	if anim_name == "jump" or anim_name == "slide":
		$AnimationPlayer.play("run")

# ポーズ解除時など、顔がワープしてしまうときに呼び出す
func reset_face_tracking_state():
	previous_face_y = face_y
	# ついでにスライディングの蓄積値もリセットしておくと安全
	upward_face_movement_while_sliding = 0.0
	print("顔トラッキングの状態をリセットしました")
