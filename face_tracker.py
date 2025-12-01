import asyncio
import websockets
import cv2
import mediapipe as mp
import json

# MediaPipeの準備 (変更なし)
mp_face_detection = mp.solutions.face_detection
face_detection = mp_face_detection.FaceDetection(model_selection=0, min_detection_confidence=0.5)

# 共有するトラッキング情報
# グローバル変数ではなく、各接続ごとに管理する
class TrackerState:
    def __init__(self):
        self.last_bbox = None
        self.last_known_face_x = 0.5
        self.last_known_face_y = 0.5

# ▼▼▼ 受信処理を別の関数に分離 ▼▼▼
async def receive_handler(websocket, state):
    """クライアントからのメッセージを受信し続けるタスク"""
    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                if data.get("command") == "reset":
                    print("リセットコマンドを受信しました。")
                    # 共有されたstateオブジェクトの値を変更する
                    state.last_bbox = None
            except json.JSONDecodeError:
                print("無効なJSONを受信しました。")
    except websockets.ConnectionClosed:
        print("受信ハンドラ: 接続が切れました。")
    finally:
        print("受信ハンドラを終了します。")

# ▼▼▼ 送信・カメラ処理を別の関数に分離 ▼▼▼
async def camera_handler(websocket, state):
    """カメラ処理を行い、座標を送信し続けるタスク"""
    cap = cv2.VideoCapture(0)   # , cv2.CAP_DSHOW)このオプションはwindowsのみのオプション

    # ▼▼▼ カメラの起動チェックとステータス通知 ▼▼▼
    if not cap.isOpened():
        print("カメラを開けませんでした。")
        await websocket.send(json.dumps({"status": "camera_failed"}))
        return # カメラが開けなければここで処理を終了

    # カメラの準備ができたことをGodotに通知
    print("カメラの準備ができました。")
    await websocket.send(json.dumps({"status": "camera_ready"}))
    
    
    
    print("トラッキングを開始します。")
    # ▲▲▲ ここまでが大きな変更点 ▲▲▲
    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            h, w, _ = frame.shape
            
            # (画像処理ロジックは以前のまま)
            if state.last_bbox is not None:
                # ROI処理...
                cx = int((state.last_bbox[0] + state.last_bbox[2] / 2) * w)
                cy = int((state.last_bbox[1] + state.last_bbox[3] / 2) * h)
                roi_size = int(max(state.last_bbox[2] * w, state.last_bbox[3] * h) * 3.5)
                x1 = max(cx - roi_size // 2, 0)
                y1 = max(cy - roi_size // 2, 0)
                x2 = min(cx + roi_size // 2, w)
                y2 = min(cy + roi_size // 2, h)
                roi_frame = frame[y1:y2, x1:x2]
                rgb_frame = cv2.cvtColor(roi_frame, cv2.COLOR_BGR2RGB)
                results = face_detection.process(rgb_frame)
            else:
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = face_detection.process(rgb_frame)
                x1, y1 = 0, 0

            detected = False
            if results.detections:
                best_detection = None
                max_area = 0
                for detection in results.detections:
                    bbox = detection.location_data.relative_bounding_box
                    area = bbox.width * bbox.height
                    if area > max_area:
                        max_area = area
                        best_detection = detection
                
                if best_detection is not None:
                    bbox = best_detection.location_data.relative_bounding_box
                    if state.last_bbox is not None:
                        abs_xmin = x1 + int(bbox.xmin * (x2 - x1))
                        abs_ymin = y1 + int(bbox.ymin * (y2 - y1))
                        abs_width = int(bbox.width * (x2 - x1))
                        abs_height = int(bbox.height * (y2 - y1))
                    else:
                        abs_xmin = int(bbox.xmin * w)
                        abs_ymin = int(bbox.ymin * h)
                        abs_width = int(bbox.width * w)
                        abs_height = int(bbox.height * h)

                    face_x = (abs_xmin + abs_width / 2) / w
                    face_y = (abs_ymin + abs_height / 2) / h
                    # 共有stateを更新
                    state.last_known_face_x = face_x
                    state.last_known_face_y = face_y
                    state.last_bbox = (abs_xmin / w, abs_ymin / h, abs_width / w, abs_height / h)
                    detected = True

                    # デバッグ描画
                    cx_draw = int(face_x * w)
                    cy_draw = int(face_y * h)
                    cv2.circle(frame, (cx_draw, cy_draw), 5, (0, 255, 0), -1)
                    cv2.rectangle(frame, (abs_xmin, abs_ymin), (abs_xmin + abs_width, abs_ymin + abs_height), (255, 0, 0), 2)

            if not detected:
                state.last_bbox = None


            # 1. まず座標を送信
            await websocket.send(json.dumps({
                "face_x": state.last_known_face_x,
                "face_y": state.last_known_face_y
            }))

            # 2. asyncioに処理を少し譲る
            await asyncio.sleep(0.01) # sleep時間を少し短くしても良い

            # 3. 最後にデバッグウィンドウを表示・更新
            cv2.imshow('Face Camera', frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
            '''
            cv2.imshow('Face Camera', frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
            
            # 座標を送信
            await websocket.send(json.dumps({
                "face_x": state.last_known_face_x,
                "face_y": state.last_known_face_y
            }))

            # 他のタスクに実行を譲る
            await asyncio.sleep(0.01)
            '''

    except websockets.ConnectionClosed:
        print("送信ハンドラ: 接続が切れました。")
    finally:
        print("カメラを解放します。")
        cap.release()
        cv2.destroyAllWindows()

# ▼▼▼ メインのハンドラを修正 ▼▼▼
async def handler(websocket, path):
    """クライアント接続時に呼ばれ、送受信タスクを起動する"""
    print(f"クライアント {websocket.remote_address} が接続しました。")
    
    # 接続ごとに独立したトラッカーの状態を生成
    tracker_state = TrackerState()

    # 受信タスクとカメラ処理タスクを作成
    receive_task = asyncio.create_task(receive_handler(websocket, tracker_state))
    camera_task = asyncio.create_task(camera_handler(websocket, tracker_state))

    # 両方のタスクが終了するまで待つ
    done, pending = await asyncio.wait(
        [receive_task, camera_task],
        return_when=asyncio.FIRST_COMPLETED,
    )

    # どちらか一方のタスクが終了したら、もう一方もキャンセルして終了
    for task in pending:
        task.cancel()
    
    print(f"クライアント {websocket.remote_address} との接続を終了します。")

# (main関数は変更なし)
async def main():
    async with websockets.serve(handler, "localhost", 1234):
        print("WebSocket Server started on ws://localhost:1234")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
