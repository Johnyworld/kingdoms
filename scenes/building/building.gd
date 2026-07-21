class_name Building extends Node2D
## 맵에 배치된 건물. 종류(building_type)에 따라 스펙을 카탈로그(BuildingTypes)에서 읽는다.
## 캠프는 건물 종류 중 하나("camp")다.
## 자원·이름·세력은 건물이 아니라 소속 영지(Territory)가 보유한다 (세력 → 영지 → 건물).
## 중심 1헥스 + 주변 6헥스 = 총 7헥스를 차지한다(현재 모든 종류 공통 발자국).
## 헥스 중 하나라도 클릭되면 게임 쪽에서 캠프 메뉴를 연다.

const LABEL_COLOR := Color.WHITE

# --- 정체성 ---
var building_type := ""            # 종류 id (예: "camp")
var territory: Territory = null:   # 소속 영지. Territory.add_building으로 연결. 변경 시 라벨 + 세력색 오토타일 갱신.
	set(value):
		territory = value
		refresh_body()   # 세력이 바뀌면 건물 오토타일 색도 갱신(라벨 포함). 미설정 레이어면 라벨만.

# --- 종류에서 오는 값 (setup 시 카탈로그에서 읽음) ---
var vision := 0

# --- 건설 상태 ---
var under_construction := false   # 참이면 건설 중(생산·시야 없음).
var remaining_turns := 0          # 완성까지 남은 턴. setup에서 build_turns로 채움.

# 수비 인원 표시값(맵 "수비 N" 배지 전용). 방어 자체는 거점 중심 타일을 점거한 그 세력 부대가 맡고,
# game.gd가 그 부대 인원으로 이 값을 채운다. 0이면 배지 없음(무방비). → docs/spec/features/camp-capture.md
var defender_count := 0

# 1차 생산 건물 상태. → docs/spec/features/production.md
var production_points := 0   # 누적 생산포인트. 매 턴 += 1(거리 기반), ≥ 거리면 자원 산출·차감.
var assigned_center = null   # 자원 입출력·거리 측정 대상 거점(Building). 건설 시 자동, 변경 가능.

# 미지정/알 수 없는 종류일 때의 중립 폴백 색(캠프로 위장하지 않도록 회색).
const FALLBACK_FILL := Color(0.5, 0.5, 0.5, 0.9)
const FALLBACK_EDGE := Color(0.3, 0.3, 0.3)
const FALLBACK_TENT := Color(0.75, 0.75, 0.75)

var cells: Array[Vector2i] = []
var _terrain: TileMapLayer
var _buildings_layer: TileMapLayer = null   # 거점 오토타일을 그리는 공유 비주얼 레이어(없으면 폴리곤 폴백)
var _center_cell: Vector2i
var _spec := {}   # 카탈로그 종류 스펙의 공유 읽기 전용 참조 — 절대 수정하지 말 것.

## 건물을 지정한 중심 셀에 종류(type_id)로 자리 잡게 한다(중심 + 이웃 6칸).
## under_construction이 참이면 건설 중 상태로 두고 remaining_turns를 카탈로그 build_turns로 채운다.
## p_buildings_layer를 주면 완성된 거점을 그 레이어에 LaPetiteTile 오토타일로 그린다.
func setup(terrain: TileMapLayer, center_cell: Vector2i, type_id: String, p_under_construction := false, p_buildings_layer: TileMapLayer = null) -> void:
	_terrain = terrain
	_buildings_layer = p_buildings_layer
	_center_cell = center_cell
	building_type = type_id
	_spec = BuildingTypes.get_type(type_id)
	vision = _spec.get("vision", 0)
	under_construction = p_under_construction
	remaining_turns = _spec.get("build_turns", 0) if p_under_construction else 0
	cells = BuildPlanner.footprint(terrain, center_cell, _spec.get("footprint", 7))   # 종류별 발자국 (배치 판정과 같은 규칙)
	refresh_body()

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
		refresh_body()   # 완성 → 오토타일 건물 등장
		return true
	refresh_body()
	return false

## 해당 셀이 건물 영역에 포함되는지.
func contains_cell(cell: Vector2i) -> bool:
	return cell in cells

## 건물 중심 셀(시야 계산 기준점).
func center_cell() -> Vector2i:
	return _center_cell

## 종류 라벨(예: "캠프").
func label() -> String:
	return _spec.get("label", "")

## 소속 세력(영지 경유 위임). 영지가 없거나 무소속이면 null. b.territory.faction 체인 대신 쓴다.
func faction():
	return territory.faction if territory != null else null

## 소속 세력 이름(영지 경유 위임). 영지가 없거나 무소속이면 "". 세력 판정의 단일 출처.
## 주의: 이름이 빈 문자열인 세력은 무소속과 구분되지 않는다(세력 이름은 카탈로그에서 항상 비어 있지 않음).
func faction_name() -> String:
	var f = faction()
	return f.name if f != null else ""

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
	refresh_body()

## 건물 몸체를 공유 비주얼 레이어에 오토타일로 다시 그린다(라벨/배지는 queue_redraw로 갱신).
## - 레이어가 없으면(테스트 등) 그리지 않고 라벨만 갱신.
## - 건설 중이면 몸체를 비우고 _draw의 흐린 foundation 폴리곤에 맡긴다.
## - 완성이면 세력색·형태(성=castle, 그 외=village)로 footprint를 칠한다(1칸=작은 집).
## setup·완성·업그레이드·영지(세력)변경 시 호출된다.
func refresh_body() -> void:
	queue_redraw()   # 라벨·배지
	if _buildings_layer == null:
		return
	for cell in cells:
		_buildings_layer.erase_cell(cell)
	if under_construction:
		return
	var idx := BuildingRenderer.terrain_index(building_type, faction_name())
	_buildings_layer.set_cells_terrain_connect(cells, BuildingRenderer.TERRAIN_SET, idx)

## 노드 제거(철거·파괴·씬 종료) 시 공유 레이어에서 자기 발자국을 지운다.
func _exit_tree() -> void:
	if _buildings_layer != null and is_instance_valid(_buildings_layer):
		for cell in cells:
			_buildings_layer.erase_cell(cell)

## 맵에 표시할 텍스트 줄 목록. 각 원소는 {text, color}. 영지에서 가져온다.
## 영지명(흰색) → 세력명(세력 색). 영지가 없으면 빈 배열.
func map_label_lines() -> Array:
	var lines := []
	if territory == null:
		return lines
	if territory.name != "":
		lines.append({"text": territory.name, "color": LABEL_COLOR})
	if faction() != null:
		lines.append({"text": faction().name, "color": faction().color})
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
	# 완성된 건물은 공유 레이어에 오토타일(마을/성/작은 집)로 그려지므로 폴리곤/텐트를 생략한다.
	# 건설 중이거나 레이어 없음일 때만 폴리곤 플레이스홀더를 그린다.
	var painted := _buildings_layer != null and not under_construction
	var center := _terrain.map_to_local(_center_cell)
	if not painted:
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
		var tent := PackedVector2Array([
			center + Vector2(0, -hh * 0.6),
			center + Vector2(hw * 0.45, hh * 0.35),
			center + Vector2(-hw * 0.45, hh * 0.35),
		])
		draw_colored_polygon(tent, tent_color)
		draw_line(center + Vector2(0, -hh * 0.6), center + Vector2(0, hh * 0.35), edge_color, 1.5, true)

	_draw_labels(center - Vector2(0, hh * 0.6))

	# 건설 중이면 남은 턴을, 완성 거점이면 수비 인원을 중심 아래에 표시(둘은 겹치지 않음).
	if under_construction:
		_draw_construction_badge(center + Vector2(0, hh * 0.7))
	elif BuildingTypes.is_center(building_type) and defender_count > 0:
		_draw_garrison_badge(center + Vector2(0, hh * 0.7), defender_count)

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
