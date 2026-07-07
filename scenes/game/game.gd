extends Node2D
## 300x300 헥스 타일 맵(초원)을 그리고, 카메라를 중앙에 배치한다.
## 카메라는 WASD 또는 마우스를 화면 가장자리에 대면 상하좌우로 이동한다.

const MAP_WIDTH := 300
const MAP_HEIGHT := 300
const GRASS_SOURCE_ID := 0
const GRASS_ATLAS := Vector2i(0, 0)

const CAM_SPEED := 900.0    # 픽셀/초
const EDGE_MARGIN := 24     # 마우스 가장자리 스크롤 감지 여백(px)

# 줌 배율(값이 작을수록 확대). 0.5 = 확대, 1 = 기본, 3 = 축소.
# Camera2D.zoom 은 값이 클수록 확대되므로 실제로는 (1 / 배율)로 변환해 적용한다.
const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0
const ZOOM_STEP := 0.1

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var camera: Camera2D = $Camera2D
@onready var hero = $Hero
@onready var overlay = $RangeOverlay

var _min_pos: Vector2
var _max_pos: Vector2
var _zoom_level := 1.0

# 현재 도달 가능한 셀 → 시작점으로부터의 거리. 클릭 이동 판정에 사용.
var _reachable: Dictionary = {}
# 주인공이 선택되었는지. 선택 상태에서만 범위 표시 + 이동이 가능하다.
var _selected := false

func _ready() -> void:
	_generate_map()
	_center_camera()
	overlay.setup(terrain)
	_place_hero()

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

## 주인공을 맵 중앙 타일에 배치한다.
func _place_hero() -> void:
	var center_cell := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
	hero.position = terrain.map_to_local(center_cell)

## 셀이 맵 범위 안인지 검사한다.
func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < MAP_WIDTH and cell.y >= 0 and cell.y < MAP_HEIGHT

## 주인공 위치에서 이동력만큼 BFS로 도달 셀을 구하고, 범위를 갱신한다.
## 거리 1~이동력 = 이동 범위(파랑), 이동력+1 = 공격 범위(빨강).
func _update_ranges() -> void:
	var start := terrain.local_to_map(hero.position)
	var move_range: int = hero.movement

	var dist := {start: 0}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var d: int = dist[cur]
		if d >= move_range + 1:
			continue  # 공격 범위(마지막 링)에서는 더 확장하지 않는다.
		for n in terrain.get_surrounding_cells(cur):
			if not _in_bounds(n) or dist.has(n):
				continue
			dist[n] = d + 1
			frontier.append(n)

	var move_cells: Array[Vector2i] = []
	var attack_cells: Array[Vector2i] = []
	for cell in dist:
		var d: int = dist[cell]
		if d == 0:
			continue  # 주인공이 선 칸은 제외
		elif d <= move_range:
			move_cells.append(cell)
		else:
			attack_cells.append(cell)

	_reachable = dist
	overlay.show_ranges(move_cells, attack_cells)

## 좌클릭 처리.
## - 선택 안 됨: 주인공 칸을 클릭하면 선택한다.
## - 선택됨: 이동 범위 칸이면 이동, 그 외 칸이면 선택 해제한다.
func _handle_click(world_pos: Vector2) -> void:
	var cell := terrain.local_to_map(terrain.to_local(world_pos))
	var hero_cell := terrain.local_to_map(hero.position)

	if not _selected:
		if cell == hero_cell:
			_select()
		return

	# 여기부터는 선택된 상태.
	if _reachable.has(cell) and _reachable[cell] >= 1 and _reachable[cell] <= hero.movement:
		hero.position = terrain.map_to_local(cell)
	_deselect()

## 주인공을 선택하고 이동/공격 범위를 표시한다.
func _select() -> void:
	_selected = true
	hero.set_selected(true)
	_update_ranges()

## 선택을 해제하고 범위 표시를 지운다.
func _deselect() -> void:
	_selected = false
	hero.set_selected(false)
	_reachable = {}
	var empty: Array[Vector2i] = []
	overlay.show_ranges(empty, empty)

## 마우스 휠로 줌 배율을 조절한다. 휠 위 = 확대, 휠 아래 = 축소.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_level - ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_level + ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(get_global_mouse_position())

## 줌 배율을 [ZOOM_MIN, ZOOM_MAX] 범위로 클램프해 카메라에 적용한다.
func _set_zoom(level: float) -> void:
	_zoom_level = clampf(level, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2.ONE / _zoom_level

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
