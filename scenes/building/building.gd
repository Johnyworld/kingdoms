class_name Building extends Node2D
## 맵에 배치된 건물. 종류(building_type)에 따라 스펙을 카탈로그(BuildingTypes)에서 읽는다.
## 캠프는 건물 종류 중 하나("camp")다.
## 중심 1헥스 + 주변 6헥스 = 총 7헥스를 차지한다(현재 모든 종류 공통 발자국).
## 헥스 중 하나라도 클릭되면 게임 쪽에서 캠프 메뉴를 연다.

const LABEL_COLOR := Color.WHITE

# --- 정체성 --- (변경 시 맵 라벨을 다시 그리도록 setter에서 queue_redraw)
var building_type := ""       # 종류 id (예: "camp")
var building_name := "":       # 인스턴스 이름(예: "파리"). Node.name과 충돌을 피해 building_name 사용.
	set(value):
		building_name = value
		queue_redraw()
var faction: Faction = null:   # 소속 세력. Faction.add_building으로 연결된다.
	set(value):
		faction = value
		queue_redraw()

# --- 종류에서 오는 값 (setup 시 카탈로그에서 채움) ---
var resources := {}
var vision := 0

# 미지정/알 수 없는 종류일 때의 중립 폴백 색(캠프로 위장하지 않도록 회색).
const FALLBACK_FILL := Color(0.5, 0.5, 0.5, 0.9)
const FALLBACK_EDGE := Color(0.3, 0.3, 0.3)
const FALLBACK_TENT := Color(0.75, 0.75, 0.75)

var cells: Array[Vector2i] = []
var _terrain: TileMapLayer
var _center_cell: Vector2i
var _spec := {}   # 카탈로그 종류 스펙의 공유 읽기 전용 참조 — 절대 수정하지 말 것.

## 건물을 지정한 중심 셀에 종류(type_id)로 자리 잡게 한다(중심 + 이웃 6칸).
func setup(terrain: TileMapLayer, center_cell: Vector2i, type_id: String) -> void:
	_terrain = terrain
	_center_cell = center_cell
	building_type = type_id
	_spec = BuildingTypes.get_type(type_id)
	vision = _spec.get("vision", 0)
	# 카탈로그 원본을 건드리지 않도록 깊은 복사본을 인스턴스가 보유한다.
	resources = (_spec.get("resources", {}) as Dictionary).duplicate(true)
	cells = [center_cell]
	for n in terrain.get_surrounding_cells(center_cell):
		cells.append(n)
	queue_redraw()

## 해당 셀이 건물 영역에 포함되는지.
func contains_cell(cell: Vector2i) -> bool:
	return cell in cells

## 건물 중심 셀(시야 계산 기준점).
func center_cell() -> Vector2i:
	return _center_cell

## 종류 라벨(예: "캠프").
func label() -> String:
	return _spec.get("label", "")

## 맵에 표시할 텍스트 줄 목록. 각 원소는 {text, color}.
## 이름(흰색) → 세력명(세력 색). 둘 다 없으면 빈 배열.
func map_label_lines() -> Array:
	var lines := []
	if building_name != "":
		lines.append({"text": building_name, "color": LABEL_COLOR})
	if faction != null:
		lines.append({"text": faction.name, "color": faction.color})
	return lines

func _draw() -> void:
	if _terrain == null:
		return
	var fill_color: Color = _spec.get("fill_color", FALLBACK_FILL)
	var edge_color: Color = _spec.get("edge_color", FALLBACK_EDGE)
	var tent_color: Color = _spec.get("tent_color", FALLBACK_TENT)

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
		draw_colored_polygon(pts, fill_color)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, edge_color, 1.5, true)

	# 중심 칸에 간단한 텐트 표시.
	var center := _terrain.map_to_local(_center_cell)
	var tent := PackedVector2Array([
		center + Vector2(0, -hh * 0.6),
		center + Vector2(hw * 0.45, hh * 0.35),
		center + Vector2(-hw * 0.45, hh * 0.35),
	])
	draw_colored_polygon(tent, tent_color)
	draw_line(center + Vector2(0, -hh * 0.6), center + Vector2(0, hh * 0.35), edge_color, 1.5, true)

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
