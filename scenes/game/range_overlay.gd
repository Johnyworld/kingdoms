extends Node2D
## 이동 범위(파랑)와 공격 범위(빨강)를 반투명 헥스로 표시하는 오버레이.
## 헥스 폴리곤은 타일셋의 tile_size를 기준으로 그려 실제 타일과 겹치게 한다.

const MOVE_COLOR := Color(0.2, 0.5, 1.0, 0.35)    # 이동 범위: 파랑
const ATTACK_COLOR := Color(1.0, 0.25, 0.25, 0.35) # 공격 범위: 빨강

var _terrain: TileMapLayer
var _move_cells: Array[Vector2i] = []
var _attack_cells: Array[Vector2i] = []

func setup(terrain: TileMapLayer) -> void:
	_terrain = terrain

## 표시할 범위를 갱신하고 다시 그린다.
func show_ranges(move_cells: Array[Vector2i], attack_cells: Array[Vector2i]) -> void:
	_move_cells = move_cells
	_attack_cells = attack_cells
	queue_redraw()

func _draw() -> void:
	if _terrain == null:
		return
	for cell in _attack_cells:
		_draw_hex(cell, ATTACK_COLOR)
	for cell in _move_cells:
		_draw_hex(cell, MOVE_COLOR)

## 한 셀 위치에 타일 크기에 맞춘 헥스(뾰족한 위/아래)를 채워 그린다.
func _draw_hex(cell: Vector2i, color: Color) -> void:
	draw_colored_polygon(HexGrid.hex_polygon(_terrain, cell), color)
