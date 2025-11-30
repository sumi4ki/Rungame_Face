# Autoloadに登録するシングルトン
extends Node

var pid: int = -1

func _ready():
    # Pythonスクリプトのパスを取得
    var script_path = ProjectSettings.globalize_path("res://face_tracker.py")

    # Pythonを実行 (戻り値はプロセスID)
    # 最後の false, false は「出力を待たない（非同期実行）」設定
    pid = OS.execute("python", [script_path], [], false, false)

    print("Python Face Tracker started. PID: ", pid)

# ゲーム終了時（ウィンドウを閉じた時など）に呼ばれる
func _exit_tree():
    if pid != -1:
        print("Killing Python process: ", pid)
        OS.kill(pid) # プロセスを強制終了