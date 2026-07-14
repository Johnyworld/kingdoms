extends Node2D
## Fog of war 오버레이. 맵 전체를 검정으로 덮되, 시야/탐험 상태에 따라 3단계로 표현한다.
## - 탐험 안 됨: 불투명 검정 (아무것도 안 보임)
## - 탐험됨 + 현재 시야 밖: 50% 검정 (지형만 보임)
## - 현재 시야 안: 그리지 않음 (완전히 보임)
##
## 맵 전체를 매 갱신마다 다시 그리면 낭비다(현재 100x100).
## 카메라에 보이는 셀 범위만 계산해 그리고, 그 범위가 바뀔 때만 다시 그린다.

const UNSEEN_COLOR := Color(0, 0, 0, 1.0)     # 미탐험: 완전 검정
const EXPLORED_COLOR := Color(0, 0, 0, 0.5)   # 탐험됨(시야 밖): 반투명 검정

var _terrain: TileMapLayer
var _map_w := 0
var _map_h := 0

# 현재 시야에 들어온 셀 집합(cell -> true).
var _visible: Dictionary = {}
# 한 번이라도 시야에 들어온 적 있는 셀 집합(cell -> true).
var _explored: Dictionary = {}

# 마지막으로 그린 화면상 셀 범위. 카메라 이동/줌 감지에 사용.
var _last_bounds := Rect2i(0, 0, -1, -1)

func setup(terrain: TileMapLayer, map_width: int, map_height: int) -> void:
	_terrain = terrain
	_map_w = map_width
	_map_h = map_height

## 현재 시야 셀 집합으로 갱신한다. 새로 보인 셀은 탐험됨으로 기록된다.
func update_visible(cells: Dictionary) -> void:
	_visible = cells
	for c in cells:
		_explored[c] = true
	queue_redraw()

## 셀이 현재 시야(_visible)에 있는지. NPC 부대 토큰 표시 판정에 쓴다.
## 탐험만 된 셀(과거에 봤지만 지금은 시야 밖)은 false.
func is_cell_visible(cell: Vector2i) -> bool:
	return _visible.has(cell)

## 셀이 한 번이라도 시야에 든 적 있는지(탐험됨). NPC 거점 표시 판정에 쓴다.
## 현재 시야뿐 아니라 과거에 봤던 셀도 true — 정적 구조물(거점)은 발견 후 계속 보인다.
func is_cell_explored(cell: Vector2i) -> bool:
	return _explored.has(cell)

func _process(_delta: float) -> void:
	# 카메라가 움직이거나 줌이 바뀌어 보이는 셀 범위가 달라지면 다시 그린다.
	if _terrain != null and _visible_cell_bounds() != _last_bounds:
		queue_redraw()

func _draw() -> void:
	if _terrain == null:
		return
	var bounds := _visible_cell_bounds()
	_last_bounds = bounds
	var ts := Vector2(_terrain.tile_set.tile_size)
	var hw := ts.x * 0.5
	var hh := ts.y * 0.5
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if _visible.has(cell):
				continue  # 완전히 보이는 칸은 안개를 그리지 않는다.
			_draw_hex(cell, EXPLORED_COLOR if _explored.has(cell) else UNSEEN_COLOR, hw, hh)

## 한 셀에 타일 크기에 맞춘 헥스를 채워 그린다.
func _draw_hex(cell: Vector2i, color: Color, hw: float, hh: float) -> void:
	var c := _terrain.map_to_local(cell)
	var pts := PackedVector2Array([
		c + Vector2(0.0, -hh),
		c + Vector2(hw, -hh * 0.5),
		c + Vector2(hw, hh * 0.5),
		c + Vector2(0.0, hh),
		c + Vector2(-hw, hh * 0.5),
		c + Vector2(-hw, -hh * 0.5),
	])
	draw_colored_polygon(pts, color)

## 카메라에 보이는 화면 영역을 셀 범위(Rect2i)로 변환한다.
## 뷰포트 네 모서리를 월드 좌표로 역변환한 뒤 셀 좌표로 바꿔 최소/최대를 취한다.
func _visible_cell_bounds() -> Rect2i:
	var inv := get_canvas_transform().affine_inverse()
	var vr := get_viewport_rect()
	var corners := [
		vr.position,
		Vector2(vr.end.x, vr.position.y),
		vr.end,
		Vector2(vr.position.x, vr.end.y),
	]
	var min_c := Vector2i(1 << 30, 1 << 30)
	var max_c := Vector2i(-(1 << 30), -(1 << 30))
	for corner in corners:
		var world: Vector2 = inv * corner
		var cell := _terrain.local_to_map(_terrain.to_local(world))
		min_c.x = mini(min_c.x, cell.x)
		min_c.y = mini(min_c.y, cell.y)
		max_c.x = maxi(max_c.x, cell.x)
		max_c.y = maxi(max_c.y, cell.y)

	# 헥스 행 오프셋과 화면 경계를 감안해 약간 여유를 둔다.
	var margin := 3
	min_c.x = clampi(min_c.x - margin, 0, _map_w - 1)
	min_c.y = clampi(min_c.y - margin, 0, _map_h - 1)
	max_c.x = clampi(max_c.x + margin, 0, _map_w - 1)
	max_c.y = clampi(max_c.y + margin, 0, _map_h - 1)
	return Rect2i(min_c, max_c - min_c + Vector2i(1, 1))
