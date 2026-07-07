extends Node2D
## 중앙 캠프. 중심 1헥스 + 주변 6헥스 = 총 7헥스를 차지한다.
## 헥스 중 하나라도 클릭되면 게임 쪽에서 캠프 메뉴를 연다.

const FILL_COLOR := Color(0.52, 0.38, 0.24, 0.9)   # 캠프 부지(흙색)
const EDGE_COLOR := Color(0.28, 0.19, 0.1)
const TENT_COLOR := Color(0.85, 0.8, 0.68)

# 자원 (초기값). 삽입 순서가 곧 메뉴 표시 순서.
var resources := {
	"밀": 50,
	"빵": 20,
	"나무": 20,
	"목재": 20,
	"철": 10,
	"철괴": 10,
}

# --- 능력치 ---
var vision := 5   # 시야

var cells: Array[Vector2i] = []
var _terrain: TileMapLayer
var _center_cell: Vector2i

## 캠프를 지정한 중심 셀에 자리 잡게 한다(중심 + 이웃 6칸).
func setup(terrain: TileMapLayer, center_cell: Vector2i) -> void:
	_terrain = terrain
	_center_cell = center_cell
	cells = [center_cell]
	for n in terrain.get_surrounding_cells(center_cell):
		cells.append(n)
	queue_redraw()

## 해당 셀이 캠프 영역에 포함되는지.
func contains_cell(cell: Vector2i) -> bool:
	return cell in cells

## 캠프 중심 셀(시야 계산 기준점).
func center_cell() -> Vector2i:
	return _center_cell

func _draw() -> void:
	if _terrain == null:
		return
	var ts := Vector2(_terrain.tile_set.tile_size)
	var hw := ts.x * 0.5
	var hh := ts.y * 0.5
	for cell in cells:
		var c := _terrain.map_to_local(cell)
		var pts := PackedVector2Array([
			c + Vector2(0.0, -hh),
			c + Vector2(hw, -hh * 0.5),
			c + Vector2(hw, hh * 0.5),
			c + Vector2(0.0, hh),
			c + Vector2(-hw, hh * 0.5),
			c + Vector2(-hw, -hh * 0.5),
		])
		draw_colored_polygon(pts, FILL_COLOR)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, EDGE_COLOR, 1.5, true)

	# 중심 칸에 간단한 텐트 표시.
	var center := _terrain.map_to_local(_center_cell)
	var tent := PackedVector2Array([
		center + Vector2(0, -hh * 0.6),
		center + Vector2(hw * 0.45, hh * 0.35),
		center + Vector2(-hw * 0.45, hh * 0.35),
	])
	draw_colored_polygon(tent, TENT_COLOR)
	draw_line(center + Vector2(0, -hh * 0.6), center + Vector2(0, hh * 0.35), EDGE_COLOR, 1.5, true)
