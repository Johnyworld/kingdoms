extends GutTest
## 카메라 줌 입력 — 마우스 휠 / 트랙패드(두 손가락 스크롤 PanGesture · 핀치 MagnifyGesture).
## game 씬을 실제로 띄우고 _unhandled_input 에 입력 이벤트를 넣어 _zoom_level 변화를 검증한다.
## 방향 규칙: 값이 작을수록 확대. 확대 = _zoom_level 감소, 축소 = _zoom_level 증가.

var game: Node2D

func before_each() -> void:
	game = load("res://scenes/game/game.tscn").instantiate()
	add_child_autofree(game)
	await wait_frames(2)   # _ready 완료 대기
	game._zoom_level = 1.0
	game._set_zoom(1.0)

func _wheel(button_index: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	ev.pressed = true
	return ev

func _pan(delta_y: float) -> InputEventPanGesture:
	var ev := InputEventPanGesture.new()
	ev.delta = Vector2(0, delta_y)
	return ev

func _magnify(factor: float) -> InputEventMagnifyGesture:
	var ev := InputEventMagnifyGesture.new()
	ev.factor = factor
	return ev

# --- 마우스 휠 (회귀) ---
func test_wheel_up_zooms_in() -> void:
	game._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_lt(game._zoom_level, 1.0, "휠 위 → 확대(_zoom_level 감소)")

func test_wheel_down_zooms_out() -> void:
	game._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_gt(game._zoom_level, 1.0, "휠 아래 → 축소(_zoom_level 증가)")

# --- 트랙패드 두 손가락 스크롤 (PanGesture) ---
func test_pan_up_zooms_in() -> void:
	game._unhandled_input(_pan(-2.0))
	assert_lt(game._zoom_level, 1.0, "위로 스크롤(delta.y<0) → 확대")

func test_pan_down_zooms_out() -> void:
	game._unhandled_input(_pan(2.0))
	assert_gt(game._zoom_level, 1.0, "아래로 스크롤(delta.y>0) → 축소")

# --- 트랙패드 핀치 (MagnifyGesture) ---
func test_pinch_out_zooms_in() -> void:
	game._unhandled_input(_magnify(1.2))
	assert_lt(game._zoom_level, 1.0, "핀치 아웃(factor>1) → 확대")

func test_pinch_in_zooms_out() -> void:
	game._unhandled_input(_magnify(0.8))
	assert_gt(game._zoom_level, 1.0, "핀치 인(factor<1) → 축소")

func test_pinch_invalid_factor_ignored() -> void:
	game._unhandled_input(_magnify(0.0))   # 비정상 입력
	assert_eq(game._zoom_level, 1.0, "factor<=0 은 무시 — zoom 불변(NaN 방지)")

# --- 경계: 클램프 ---
func test_zoom_clamped_to_min() -> void:
	for i in 100:
		game._unhandled_input(_magnify(2.0))   # 계속 확대
	assert_eq(game._zoom_level, 0.5, "확대는 ZOOM_MIN(0.5)에서 멈춤")

func test_zoom_clamped_to_max() -> void:
	for i in 100:
		game._unhandled_input(_pan(10.0))       # 계속 축소
	assert_eq(game._zoom_level, 3.0, "축소는 ZOOM_MAX(3.0)에서 멈춤")
