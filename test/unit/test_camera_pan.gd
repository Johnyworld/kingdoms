extends GutTest
## 카메라 엣지 팬 — 화면 가장자리에 커서를 대면 방향 화살표로 바뀌고, 좌클릭을 누르는 동안 그 방향으로 팬.
## _edge_cursor_shape(dir) 는 팬 방향 → 커서 모양 매핑(순수 함수)을 검증한다. → docs/spec/features/map-and-camera.md

var game: Node2D

func before_each() -> void:
	game = load("res://scenes/game/game.tscn").instantiate()
	add_child_autofree(game)
	await wait_frames(2)   # _ready 완료 대기

# --- 커서 모양 매핑 ---
func test_no_edge_is_default_arrow() -> void:
	assert_eq(game._edge_cursor_shape(Vector2.ZERO), Input.CURSOR_ARROW, "가장자리 아님 → 기본 화살표")

func test_vertical_edge_is_vsize() -> void:
	assert_eq(game._edge_cursor_shape(Vector2(0, -1)), Input.CURSOR_VSIZE, "위 → 상하 화살표")
	assert_eq(game._edge_cursor_shape(Vector2(0, 1)), Input.CURSOR_VSIZE, "아래 → 상하 화살표")

func test_horizontal_edge_is_hsize() -> void:
	assert_eq(game._edge_cursor_shape(Vector2(-1, 0)), Input.CURSOR_HSIZE, "좌 → 좌우 화살표")
	assert_eq(game._edge_cursor_shape(Vector2(1, 0)), Input.CURSOR_HSIZE, "우 → 좌우 화살표")

func test_diagonal_fdiag() -> void:
	# ↗(우상) · ↙(좌하) = FDIAG (dir.x * dir.y < 0)
	assert_eq(game._edge_cursor_shape(Vector2(1, -1)), Input.CURSOR_FDIAGSIZE, "우상 → / 화살표")
	assert_eq(game._edge_cursor_shape(Vector2(-1, 1)), Input.CURSOR_FDIAGSIZE, "좌하 → / 화살표")

func test_diagonal_bdiag() -> void:
	# ↘(우하) · ↖(좌상) = BDIAG (dir.x * dir.y > 0)
	assert_eq(game._edge_cursor_shape(Vector2(1, 1)), Input.CURSOR_BDIAGSIZE, "우하 → \\ 화살표")
	assert_eq(game._edge_cursor_shape(Vector2(-1, -1)), Input.CURSOR_BDIAGSIZE, "좌상 → \\ 화살표")

# --- 가장자리 팬 방향(_edge_dir_for: 마우스 좌표·뷰 크기 → 방향) ---
const VIEW := Vector2(800, 600)   # EDGE_MARGIN = 24px

func test_interior_no_pan() -> void:
	assert_eq(game._edge_dir_for(Vector2(400, 300), VIEW), Vector2.ZERO, "중앙 → 팬 없음")

func test_left_edge() -> void:
	assert_eq(game._edge_dir_for(Vector2(10, 300), VIEW), Vector2(-1, 0), "좌 가장자리 → 좌로")

func test_right_edge() -> void:
	assert_eq(game._edge_dir_for(Vector2(790, 300), VIEW), Vector2(1, 0), "우 가장자리 → 우로")

func test_top_edge() -> void:
	assert_eq(game._edge_dir_for(Vector2(400, 10), VIEW), Vector2(0, -1), "위 가장자리 → 위로")

func test_bottom_edge() -> void:
	assert_eq(game._edge_dir_for(Vector2(400, 590), VIEW), Vector2(0, 1), "아래 가장자리 → 아래로")

func test_corner_is_diagonal() -> void:
	assert_eq(game._edge_dir_for(Vector2(5, 5), VIEW), Vector2(-1, -1), "좌상 모서리 → 대각(좌상)")
	assert_eq(game._edge_dir_for(Vector2(795, 595), VIEW), Vector2(1, 1), "우하 모서리 → 대각(우하)")

func test_just_inside_margin_no_pan() -> void:
	# EDGE_MARGIN=24 → 경계 바로 안쪽(25px)은 팬 없음
	assert_eq(game._edge_dir_for(Vector2(25, 300), VIEW), Vector2.ZERO, "여백 바로 안쪽 → 팬 없음")
