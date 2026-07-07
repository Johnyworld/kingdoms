extends Node2D
## 건설 모드에서 배치 대상 footprint를 미리보기로 표시한다.
## 배치 가능=초록, 불가=빨강. 건설 모드가 아니면(clear 후) 아무것도 그리지 않는다.
## 다른 오버레이(RangeOverlay·Fog)처럼 타일셋 tile_size 기준 헥스를 그린다.

const VALID_COLOR := Color(0.3, 0.9, 0.4, 0.4)    # 배치 가능: 초록
const INVALID_COLOR := Color(1.0, 0.3, 0.3, 0.4)  # 배치 불가: 빨강

var _terrain: TileMapLayer
var _cells: Array[Vector2i] = []
var _valid := false
var _active := false

func setup(terrain: TileMapLayer) -> void:
	_terrain = terrain

## 미리보기 셀과 유효 여부를 갱신하고 다시 그린다.
func show_preview(cells: Array[Vector2i], valid: bool) -> void:
	_cells = cells
	_valid = valid
	_active = true
	queue_redraw()

## 미리보기를 지운다(건설 모드 종료).
func clear() -> void:
	_active = false
	_cells = []
	queue_redraw()

func _draw() -> void:
	if _terrain == null or not _active:
		return
	var color := VALID_COLOR if _valid else INVALID_COLOR
	for cell in _cells:
		_draw_hex(cell, color)

## 한 셀 위치에 타일 크기에 맞춘 헥스(뾰족한 위/아래)를 채워 그린다.
func _draw_hex(cell: Vector2i, color: Color) -> void:
	draw_colored_polygon(HexGrid.hex_polygon(_terrain, cell), color)
