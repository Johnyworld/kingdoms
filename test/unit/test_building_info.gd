extends GutTest
## 건물 정보 패널 — 캠프가 아닌 건물(농장) 클릭 시 우측 상단에
## 종류·상태·시야·영지·생산을 표시.

const MAP := 41
const BLUE := Color(0.2, 0.3, 0.8)

var panel: CanvasLayer
var terrain: TileMapLayer

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)
	panel = load("res://scenes/building/building_info.gd").new()
	add_child_autofree(panel)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

## 지정 종류·건설 상태의 건물을 만든다.
func _building(type_id: String, under_construction := false) -> Node2D:
	var b: Node2D = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.setup(terrain, _center(), type_id, under_construction)
	return b

## 이름·세력을 가진 영지에 건물을 편입한다.
func _join_territory(b: Node2D) -> void:
	var f = load("res://scenes/faction/faction.gd").new("프랑스", BLUE)
	var t = load("res://scenes/territory/territory.gd").new("파리", {})
	f.add_territory(t)
	t.add_building(b)

## 정보 리스트의 모든 라벨 텍스트를 이어붙인다(포함 검사용).
func _info_text() -> String:
	var parts := []
	for child in panel._info_list.get_children():
		parts.append((child as Label).text)
	return " / ".join(parts)

func test_title_is_building_label() -> void:
	panel.open(_building("farm"))
	assert_eq(panel._title.text, "농장", "제목 = 건물 종류 라벨")

func test_summary_complete_shows_state_and_vision() -> void:
	panel.open(_building("farm"))
	assert_eq(panel._summary.text, "완성 · 시야 4", "완성 농장 요약 = 완성 · 시야 4")

func test_info_list_has_territory_faction_and_production() -> void:
	var b := _building("farm")
	_join_territory(b)
	panel.open(b)
	var text := _info_text()
	assert_string_contains(text, "파리", "영지명 포함")
	assert_string_contains(text, "프랑스", "세력명 포함")
	assert_string_contains(text, "밀", "생산 자원(밀) 포함")

func test_summary_under_construction_shows_remaining_turns() -> void:
	panel.open(_building("farm", true))
	assert_eq(panel._summary.text, "건설 중 3턴 · 시야 4", "건설 중 요약 = 남은 턴 + 시야")

func test_production_shown_even_under_construction() -> void:
	var b := _building("farm", true)
	_join_territory(b)
	panel.open(b)
	assert_string_contains(_info_text(), "밀", "건설 중에도 완성 시 생산량 표시")

func test_no_territory_hides_territory_lines() -> void:
	panel.open(_building("farm"))
	var text := _info_text()
	assert_false(text.contains("파리"), "영지 없으면 영지명 줄 없음")
	assert_false(text.contains("프랑스"), "영지 없으면 세력명 줄 없음")

func test_reopen_replaces_info_lines() -> void:
	var with_territory := _building("farm")
	_join_territory(with_territory)
	panel.open(with_territory)
	panel.open(_building("farm"))   # 영지 없는 건물로 재오픈
	assert_false(_info_text().contains("파리"), "재오픈 시 이전 영지 줄이 남지 않음")

func test_camp_shows_garrison_count() -> void:
	var b := _building("camp")
	b.garrison = load("res://scenes/party/unit_types.gd").make_garrison(3)
	panel.open(b)
	assert_string_contains(_info_text(), "수비대 3명", "캠프는 수비대 수 표시")

func test_farm_no_garrison_line() -> void:
	panel.open(_building("farm"))
	assert_false(_info_text().contains("수비대"), "캠프 아닌 건물은 수비대 줄 없음")

func test_camp_shows_territory_faction_no_production() -> void:
	# NPC 거점(캠프)도 이 패널로 정보만 표시한다: 제목 "캠프" · 요약 "완성 · 시야 5" · 영지·세력, 생산 줄 없음.
	var b := _building("camp")
	_join_territory(b)
	panel.open(b)
	assert_eq(panel._title.text, "캠프", "제목 = 캠프")
	assert_eq(panel._summary.text, "완성 · 시야 5", "완성 캠프 요약 = 완성 · 시야 5")
	var text := _info_text()
	assert_string_contains(text, "파리", "영지명 포함")
	assert_string_contains(text, "프랑스", "세력명 포함")
	assert_false(text.contains("/ 턴"), "캠프는 생산 줄 없음")

func test_open_shows_close_hides() -> void:
	panel.open(_building("farm"))
	assert_true(panel.visible, "open 후 표시")
	panel.close()
	assert_false(panel.visible, "close 후 숨김")
