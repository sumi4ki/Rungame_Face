extends Node

# enum を使うと、"Easy"などの文字列を直接使うより安全で分かりやすくなる
enum Difficulty { EASY, MEDIUM, HARD }

# 現在のチェックポイントを保存する変数。初期値はEASY。
var start_section: Difficulty = Difficulty.EASY

# スライディングのモードを定義
enum SlideMode { TIMER, HOLD }
# 現在のスライディングモードを保持する変数（デフォルトはTIMER）
var current_slide_mode: SlideMode = SlideMode.TIMER

var jump_velocity_threshold := 2.0 # 顔を速く動かしたときだけ反応
var sliding_velocity_threshold := 1.5 # スライディングは発動しづらいから1.5中心にする

# タイトル画面から「はじめから」プレイする時に呼び出すリセット関数
func reset_progress():
    start_section = Difficulty.EASY