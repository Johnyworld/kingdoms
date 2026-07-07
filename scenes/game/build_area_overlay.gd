extends Node2D
## 건설 모드에서 "건물을 지을 수 있는 영역"(영지 시야)의 바깥 윤곽선을 파랑 선으로 표시한다.
## 시야는 배치하는 동안 변하지 않으므로 건설 모드 진입 시 한 번 계산해 그리고, 종료 시 지운다.
## Node2D 월드 좌표라 카메라 이동·줌에는 자동으로 따라간다.

const OUTLINE_COLOR := Color(0.2, 0.5, 1.0, 0.9)  # 파랑
const OUTLINE_WIDTH := 3.0

var _terrain: TileMapLayer
var _segments: Array = []

func setup(terrain: TileMapLayer) -> void:
	_terrain = terrain

## 영역 셀 집합({cell: true} 또는 배열)의 바깥 윤곽선을 계산하고 다시 그린다.
func show_area(cells) -> void:
	_segments = HexGrid.region_outline(_terrain, cells)
	queue_redraw()

## 윤곽선을 지운다(건설 모드 종료).
func clear() -> void:
	_segments = []
	queue_redraw()

func _draw() -> void:
	for seg in _segments:
		draw_line(seg[0], seg[1], OUTLINE_COLOR, OUTLINE_WIDTH)
