class_name Building extends Node2D
## 맵에 배치된 건물. 종류(building_type)에 따라 스펙을 카탈로그(BuildingTypes)에서 읽는다.
## 캠프는 건물 종류 중 하나("camp")다.
## 자원·이름·세력은 건물이 아니라 소속 영지(Territory)가 보유한다 (세력 → 영지 → 건물).
## 중심 1헥스 + 주변 6헥스 = 총 7헥스를 차지한다(현재 모든 종류 공통 발자국).
## 헥스 중 하나라도 클릭되면 게임 쪽에서 캠프 메뉴를 연다.

const LABEL_COLOR := Color.WHITE

# --- 정체성 ---
var building_type := ""            # 종류 id (예: "camp")
var territory: Territory = null:   # 소속 영지. Territory.add_building으로 연결. 변경 시 맵 라벨 갱신.
	set(value):
		territory = value
		queue_redraw()

# --- 종류에서 오는 값 (setup 시 카탈로그에서 읽음) ---
var vision := 0

# --- 건설 상태 ---
var under_construction := false   # 참이면 건설 중(생산·시야 없음).
var remaining_turns := 0          # 완성까지 남은 턴. setup에서 build_turns로 채움.

# 수비 인원 표시값(맵 "수비 N" 배지 전용). 방어 자체는 거점 중심 타일을 점거한 그 세력 부대가 맡고,
# game.gd가 그 부대 인원으로 이 값을 채운다. 0이면 배지 없음(무방비). → docs/spec/features/camp-capture.md
var defender_count := 0

# 성벽 단계. 0=없음, ≥1=성벽(적 접근 차단). 마을회관·성만 [성벽 건설]로 올린다. → docs/spec/features/wall.md
var wall_level := 0

# 성벽 내구도. 성벽 건설 시 Siege.WALL_MAX_HP로 채우고, 투석으로 깎여 0이면 붕괴(game.gd가 wall_level→0). → docs/spec/features/wall.md
var wall_hp := 0

# 성문 내구도. 성벽 건설 시 Siege.GATE_MAX_HP로 채우고, 충차·투석으로 깎여 0이면 그 면 통로 개방(성벽 유지). → docs/spec/features/wall.md 성문
var gate_hp := 0

# 1차 생산 건물 상태. → docs/spec/features/production.md
var production_points := 0   # 누적 생산포인트. 매 턴 += 1(거리 기반), ≥ 거리면 자원 산출·차감.
var assigned_center = null   # 자원 입출력·거리 측정 대상 거점(Building). 건설 시 자동, 변경 가능.

# 미지정/알 수 없는 종류일 때의 중립 폴백 색(캠프로 위장하지 않도록 회색).
const FALLBACK_FILL := Color(0.5, 0.5, 0.5, 0.9)
const FALLBACK_EDGE := Color(0.3, 0.3, 0.3)
const FALLBACK_TENT := Color(0.75, 0.75, 0.75)

var cells: Array[Vector2i] = []
var _terrain: TileMapLayer
var _center_cell: Vector2i
var _spec := {}   # 카탈로그 종류 스펙의 공유 읽기 전용 참조 — 절대 수정하지 말 것.

## 건물을 지정한 중심 셀에 종류(type_id)로 자리 잡게 한다(중심 + 이웃 6칸).
## under_construction이 참이면 건설 중 상태로 두고 remaining_turns를 카탈로그 build_turns로 채운다.
func setup(terrain: TileMapLayer, center_cell: Vector2i, type_id: String, p_under_construction := false) -> void:
	_terrain = terrain
	_center_cell = center_cell
	building_type = type_id
	_spec = BuildingTypes.get_type(type_id)
	vision = _spec.get("vision", 0)
	under_construction = p_under_construction
	remaining_turns = _spec.get("build_turns", 0) if p_under_construction else 0
	cells = BuildPlanner.footprint(terrain, center_cell, _spec.get("footprint", 7))   # 종류별 발자국 (배치 판정과 같은 규칙)
	queue_redraw()

## 건설이 끝났는지(건설 중이 아니면 참).
func is_complete() -> bool:
	return not under_construction

## 건설을 1턴 진행한다. 이미 완성이면 no-op(false). 건설 중이면 남은 턴을 줄이고,
## 이번 호출로 완성됐으면 true, 아직 진행 중이면 false.
func advance_construction() -> bool:
	if not under_construction:
		return false
	remaining_turns -= 1
	if remaining_turns <= 0:
		remaining_turns = 0
		under_construction = false
		queue_redraw()
		return true
	queue_redraw()
	return false

## 해당 셀이 건물 영역에 포함되는지.
func contains_cell(cell: Vector2i) -> bool:
	return cell in cells

## 건물 중심 셀(시야 계산 기준점).
func center_cell() -> Vector2i:
	return _center_cell

## 거점에 성벽이 있는지(적 접근 차단 판정). → docs/spec/features/wall.md
func is_walled() -> bool:
	return wall_level > 0

## 성문이 놓인 ring 한 면(footprint 이웃 6칸 중 결정론적 한 칸 — 좌표순 첫 칸). 위치 고정. → wall.md 성문
func gate_cell() -> Vector2i:
	var ring: Array[Vector2i] = []
	for c in cells:
		if c != _center_cell:
			ring.append(c)
	if ring.is_empty():
		return _center_cell   # footprint 1(성벽 불가 — 실사용 없음)
	ring.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.y < b.y)
	return ring[0]

## 성문이 부서져 그 면 통로가 열렸는지(성벽 있고 성문 내구도 0). → wall.md 성문
func gate_broken() -> bool:
	return is_walled() and gate_hp <= 0

## 종류 라벨(예: "캠프").
func label() -> String:
	return _spec.get("label", "")

## 1차 생산 건물인지(카탈로그 primary_production). 배치 규칙·생산포인트 경로 게이트. → production.md
func is_primary_production() -> bool:
	return _spec.get("primary_production", false)

## 산출 자원 id(카탈로그 produces, 아니면 ""). 농장="식량", 벌목소="목재", 철광="철", 금광="금".
func produces() -> String:
	return _spec.get("produces", "")

## 건설 가능 지형 source_id 리스트(카탈로그 buildable_terrains, 없으면 []=제한 없음). → Terrain
func buildable_terrains() -> Array:
	return _spec.get("buildable_terrains", [])

## 매 턴 생산포인트를 1 올리고, distance마다 자원 1 산출(PP 차감). 산출 수 반환. → production.md
## distance≤0·produces()==""면 0(no-op). 거리 기반(인원 없음) — 가까울수록 빠르다.
func tick_production(distance: int) -> int:
	if distance <= 0 or produces() == "":
		return 0
	production_points += 1
	var produced := 0
	while production_points >= distance:
		production_points -= distance
		produced += 1
	return produced

## 생산력 표시값 = 1 / distance(턴당 자원, 소수). distance≤0이면 0.
func production_rate(distance: int) -> float:
	return 0.0 if distance <= 0 else 1.0 / float(distance)

## 영지 인구 상한에 더하는 값. 건설 중에는 0(완성 건물만 기여). 완성 후 카탈로그 pop_cap(없으면 0).
## 티어별: 캠프 0 · 마을회관 10 · 성 20, 집 +2. production()과 같은 건설-게이트 패턴. Territory.population_cap()이 합산한다.
func pop_cap() -> int:
	if under_construction:
		return 0
	return _spec.get("pop_cap", 0)

## 완성 건물 철거 시 돌려받는 salvage 자재(자원명→수량). 순수 카탈로그 demolish_refund(없으면 빈 Dictionary).
func demolish_refund() -> Dictionary:
	return _spec.get("demolish_refund", {})

## 철거 시 실제 환급 자재. 완성이면 demolish_refund(salvage), 건설 중이면 낸 build_cost를 진행도 비례로 회수.
## 건설 중 = floor(build_cost[자원] × remaining_turns / build_turns) — 안 쓴 자재만. 몫이 0인 자원은 생략.
## build_turns <= 0이면(즉시 건물 방어) build_cost 전액. Territory.demolish·철거 미리보기가 쓴다.
func refund_on_demolish() -> Dictionary:
	if is_complete():
		return demolish_refund()
	var cost: Dictionary = _spec.get("build_cost", {})
	var bt: int = _spec.get("build_turns", 0)
	if bt <= 0:
		return cost.duplicate()
	var out: Dictionary = {}
	for res_name in cost:
		var amount: int = cost[res_name] * remaining_turns / bt   # 정수 나눗셈(내림)
		if amount > 0:
			out[res_name] = amount
	return out

## 폐지됨 — 인구는 병력 전용 예약이라 건물이 고용하지 않는다. 카탈로그에 required_pop 키가 없어 항상 0. → docs/spec/data/resources.md
func required_pop() -> int:
	return _spec.get("required_pop", 0)

## 거점을 다음 티어(type_id)로 제자리 업그레이드한다: 종류·스펙·시야·점유 셀을 교체하고 완성 상태로 둔다.
## 위치(중심)·영지(territory)는 그대로 유지한다. 방어 부대는 별도 부대라 무관. 비용 지불은 호출부가 먼저 한다.
func upgrade_to(type_id: String) -> void:
	building_type = type_id
	_spec = BuildingTypes.get_type(type_id)
	vision = _spec.get("vision", 0)
	under_construction = false
	remaining_turns = 0
	cells = BuildPlanner.footprint(_terrain, _center_cell, _spec.get("footprint", 7))
	queue_redraw()

## 맵에 표시할 텍스트 줄 목록. 각 원소는 {text, color}. 영지에서 가져온다.
## 영지명(흰색) → 세력명(세력 색). 영지가 없으면 빈 배열.
func map_label_lines() -> Array:
	var lines := []
	if territory == null:
		return lines
	if territory.name != "":
		lines.append({"text": territory.name, "color": LABEL_COLOR})
	if territory.faction != null:
		lines.append({"text": territory.faction.name, "color": territory.faction.color})
	return lines

func _draw() -> void:
	if _terrain == null:
		return
	var fill_color: Color = _spec.get("fill_color", FALLBACK_FILL)
	var edge_color: Color = _spec.get("edge_color", FALLBACK_EDGE)
	var tent_color: Color = _spec.get("tent_color", FALLBACK_TENT)

	# 건설 중이면 흐릿하게 그려 미완성을 표현한다.
	if under_construction:
		fill_color.a *= 0.4
		edge_color.a *= 0.6
		tent_color.a *= 0.6

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

	if is_walled():
		_draw_wall_ring(center)
		_draw_gate(center)

	_draw_labels(center - Vector2(0, hh * 0.6))

	# 건설 중이면 남은 턴을, 완성 거점이면 수비 인원을 중심 아래에 표시(둘은 겹치지 않음).
	if under_construction:
		_draw_construction_badge(center + Vector2(0, hh * 0.7))
	elif BuildingTypes.is_center(building_type) and defender_count > 0:
		_draw_garrison_badge(center + Vector2(0, hh * 0.7), defender_count)

## 성문 표시 — gate_cell 방향에 마커. 온전(갈색)→손상(붉게), 부서지면(gate_broken) 열린 색(초록). → docs/spec/features/wall.md 성문
func _draw_gate(center: Vector2) -> void:
	var pos := _terrain.map_to_local(gate_cell())
	var color: Color
	if gate_broken():
		color = Color(0.35, 0.75, 0.4)   # 열림(통로)
	else:
		var ratio := clampf(float(gate_hp) / float(Siege.GATE_MAX_HP), 0.0, 1.0)
		color = Color(0.85, 0.25, 0.2).lerp(Color(0.55, 0.4, 0.2), ratio)   # 손상→온전(갈색 문)
	draw_circle((center + pos) * 0.5, 5.0, color)

## 성벽 링을 그린다 — 중심을 두른 이웃 6칸의 중심을 잇는 육각 테두리(회색 두꺼운 선). → docs/spec/features/wall.md
func _draw_wall_ring(center: Vector2) -> void:
	var pts: Array = []
	for cell in cells:
		if cell == _center_cell:
			continue
		pts.append(_terrain.map_to_local(cell))
	if pts.size() < 2:
		return
	pts.sort_custom(func(a, b): return (a - center).angle() < (b - center).angle())   # 각도순 정렬 → 링 순서
	pts.append(pts[0])   # 닫힌 고리
	# 내구도 비율로 색 보간: 온전(회색) → 손상(붉게). → docs/spec/features/wall.md
	var ratio := clampf(float(wall_hp) / float(Siege.WALL_MAX_HP), 0.0, 1.0)
	var ring_color := Color(0.85, 0.25, 0.2).lerp(Color(0.62, 0.62, 0.68), ratio)
	draw_polyline(PackedVector2Array(pts), ring_color, 3.0, true)

## 수비 인원 표시("수비 N")를 앵커 중앙에 그린다(완성 거점, 중심 점거 방어 부대 있을 때).
func _draw_garrison_badge(anchor: Vector2, count: int) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 12
	var text := "수비 %d" % count
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(anchor.x - w * 0.5, anchor.y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.85, 0.85, 0.95))

## 건설 중 표시("건설 중 N")를 앵커 중앙에 그린다.
func _draw_construction_badge(anchor: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 12
	var text := "건설 중 %d" % remaining_turns
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(anchor.x - w * 0.5, anchor.y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.9, 0.4))

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
