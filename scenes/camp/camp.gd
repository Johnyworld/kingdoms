class_name Camp extends Node2D
## 중앙 캠프. 중심 1헥스 + 주변 6헥스 = 총 7헥스를 차지한다.
## 헥스 중 하나라도 클릭되면 게임 쪽에서 캠프 메뉴를 연다.
## 캠프는 이름을 가지며 하나의 세력(Faction)에 소속된다.

const FILL_COLOR := Color(0.52, 0.38, 0.24, 0.9)   # 캠프 부지(흙색)
const EDGE_COLOR := Color(0.28, 0.19, 0.1)
const TENT_COLOR := Color(0.85, 0.8, 0.68)

# --- 정체성 --- (변경 시 맵 라벨을 다시 그리도록 setter에서 queue_redraw)
var camp_name := "":        # 캠프 이름(예: "파리"). Node.name과 충돌을 피해 camp_name 사용.
	set(value):
		camp_name = value
		queue_redraw()
var faction: Faction = null: # 소속 세력. Faction.add_camp로 연결된다.
	set(value):
		faction = value
		queue_redraw()

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

## 맵에 표시할 텍스트 줄 목록. 각 원소는 {text, color}.
## 이름(흰색) → 세력명(세력 색). 둘 다 없으면 빈 배열.
func map_label_lines() -> Array:
	var lines := []
	if camp_name != "":
		lines.append({"text": camp_name, "color": Color.WHITE})
	if faction != null:
		lines.append({"text": faction.name, "color": faction.color})
	return lines

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

	_draw_labels(center - Vector2(0, hh * 0.6))

## 텐트 위쪽 중앙에 이름·세력 줄을 위→아래로 그린다.
func _draw_labels(anchor: Vector2) -> void:
	var lines := map_label_lines()
	if lines.is_empty():
		return
	var font := ThemeDB.fallback_font
	var font_size := 12
	var line_h := font_size + 3
	# anchor를 맨 아랫줄의 baseline으로 삼아 위로 쌓아 올린다.
	var baseline := anchor.y - (lines.size() - 1) * line_h
	for line in lines:
		var text: String = line["text"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(anchor.x - w * 0.5, baseline), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, line["color"])
		baseline += line_h
