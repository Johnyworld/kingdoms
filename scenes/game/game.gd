extends Node2D
## 300x300 헥스 타일 맵(초원)을 그리고, 카메라를 중앙에 배치한다.
## 카메라는 WASD 또는 마우스를 화면 가장자리에 대면 상하좌우로 이동한다.

const MAP_WIDTH := 300
const MAP_HEIGHT := 300
const GRASS_SOURCE_ID := 0
const GRASS_ATLAS := Vector2i(0, 0)

const CAM_SPEED := 900.0    # 픽셀/초
const EDGE_MARGIN := 24     # 마우스 가장자리 스크롤 감지 여백(px)

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var camera: Camera2D = $Camera2D

var _min_pos: Vector2
var _max_pos: Vector2

func _ready() -> void:
	_generate_map()
	_center_camera()

## 맵 전체를 초원 타일로 채운다.
func _generate_map() -> void:
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			terrain.set_cell(Vector2i(x, y), GRASS_SOURCE_ID, GRASS_ATLAS)

	# 카메라 이동 범위(월드 좌표) 계산 — 맵 밖으로 벗어나지 않도록 클램프용.
	var corner_a := terrain.map_to_local(Vector2i(0, 0))
	var corner_b := terrain.map_to_local(Vector2i(MAP_WIDTH - 1, MAP_HEIGHT - 1))
	_min_pos = Vector2(min(corner_a.x, corner_b.x), min(corner_a.y, corner_b.y))
	_max_pos = Vector2(max(corner_a.x, corner_b.x), max(corner_a.y, corner_b.y))

## 카메라를 맵 중앙 타일로 이동시킨다.
func _center_camera() -> void:
	var center_cell := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
	camera.position = terrain.map_to_local(center_cell)
	camera.make_current()

func _process(delta: float) -> void:
	var dir := Vector2.ZERO

	# 키보드 (WASD)
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0

	# 마우스 화면 가장자리
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
	var view_size := vp.get_visible_rect().size
	if mouse.x <= EDGE_MARGIN:
		dir.x -= 1.0
	elif mouse.x >= view_size.x - EDGE_MARGIN:
		dir.x += 1.0
	if mouse.y <= EDGE_MARGIN:
		dir.y -= 1.0
	elif mouse.y >= view_size.y - EDGE_MARGIN:
		dir.y += 1.0

	if dir != Vector2.ZERO:
		camera.position += dir.normalized() * CAM_SPEED * delta
		camera.position.x = clampf(camera.position.x, _min_pos.x, _max_pos.x)
		camera.position.y = clampf(camera.position.y, _min_pos.y, _max_pos.y)
