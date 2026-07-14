extends GutTest
## 캠프 메뉴 UI — 클릭한 건물의 영지 정보(이름/세력/자원) 표시. 자원 4종 축소·상거래 제거 반영.

const BLUE := Color(0.2, 0.3, 0.8)
# 캠프 초기 자원 순서(목재·식량·철·금·인구).
const RES := {"목재": 40, "식량": 50, "철": 10, "금": 0, "인구": 10}

var menu: CanvasLayer
var terrain: TileMapLayer
var building: Node2D

func before_each() -> void:
	menu = load("res://scenes/camp/camp_menu.gd").new()
	add_child_autofree(menu)
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)
	building = load("res://scenes/building/building.gd").new()
	add_child_autofree(building)
	building.setup(terrain, Vector2i(20, 20), "camp")

func _join_territory() -> Object:
	var f = load("res://scenes/faction/faction.gd").new("프랑스", BLUE)
	var t = load("res://scenes/territory/territory.gd").new("파리", RES.duplicate(true))
	f.add_territory(t)
	t.add_building(building)
	return t

## 자원이 부족한(빈) 영지에 건물을 편입한다.
func _join_poor_territory() -> Object:
	var t = load("res://scenes/territory/territory.gd").new("가난", {})
	t.add_building(building)
	return t

func test_shows_territory_name_and_faction() -> void:
	_join_territory()
	menu.open(building)
	assert_eq(menu._camp_title.text, "파리", "제목 라벨 = 영지 이름")
	assert_eq(menu._faction_label.text, "프랑스", "세력 라벨 = 세력명")

func test_faction_label_color() -> void:
	_join_territory()
	menu.open(building)
	assert_eq(menu._faction_label.get_theme_color("font_color"), BLUE, "세력 라벨 색상 = 세력 색상")

func test_no_territory_empty_label() -> void:
	menu.open(building)
	assert_eq(menu._faction_label.text, "", "영지 없으면 세력 라벨 빈 문자열")

func test_faction_color_cleared_on_reopen() -> void:
	_join_territory()
	menu.open(building)
	var bare = load("res://scenes/building/building.gd").new()
	add_child_autofree(bare)
	bare.setup(terrain, Vector2i(25, 25), "camp")
	menu.open(bare)
	assert_false(menu._faction_label.has_theme_color_override("font_color"), "재오픈 시 이전 세력 색상 제거")

func test_resource_grid_filled() -> void:
	_join_territory()
	menu.open(building)
	# 자원 5종 × 2열(이름/값) = 10개 자식.
	assert_eq(menu._res_grid.get_child_count(), 10, "자원 그리드가 영지 자원 5종으로 채워진다")

## 지정 거점 티어 건물 + 자원 영지를 만들어 그 거점을 반환한다.
func _center(type_id: String, res := RES) -> Node2D:
	var b = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.setup(terrain, Vector2i(20, 20), type_id)
	var t = load("res://scenes/territory/territory.gd").new("파리", res.duplicate(true))
	t.add_building(b)
	return b

func test_population_row_shows_cap() -> void:
	# 마을회관 거점(상한 10) + 인구 10 → "10 / 10". 인구는 5번째 자원(인덱스 8·9).
	menu.open(_center("town_hall"))
	assert_eq((menu._res_grid.get_child(8) as Label).text, "인구", "5번째 행은 인구")
	assert_eq((menu._res_grid.get_child(9) as Label).text, "10 / 10", "인구 값은 현재/상한")

# --- 건축 리스트 + 선행 티어 게이트. BUILDABLE 순서 = [farm(0), lumberjack(1), iron_mine(2), gold_mine(3), house(4), siege_workshop(5)]. ---

func _item(idx: int) -> Button:
	return menu._build_list.get_child(idx) as Button

func test_build_list_six_items_primary_active() -> void:
	menu.open(_center("camp"))  # 캠프 티어
	menu._on_build_pressed()
	assert_true(menu._build_list.visible, "건축 후 리스트 표시")
	assert_eq(menu._build_list.get_child_count(), 6, "건축 가능 6종(1차 4 + 집 + 공성 작업장)")
	assert_false(_item(0).disabled, "농장(선행 camp)은 캠프 티어부터 활성")

func test_item_text_has_label_and_cost() -> void:
	menu.open(_center("camp"))
	menu._on_build_pressed()
	var text := _item(0).text  # 농장
	assert_string_contains(text, "농장", "항목에 라벨 포함")
	assert_string_contains(text, "목재", "항목에 비용(목재) 포함")

func test_primary_active_house_locked_at_camp_tier() -> void:
	menu.open(_center("camp"))  # 캠프 티어(마을회관 미만)
	menu._on_build_pressed()
	assert_false(_item(0).disabled, "캠프 티어에서 농장(1차 생산) 활성")
	assert_true(_item(4).disabled, "캠프 티어면 집 비활성(선행 마을회관)")
	assert_string_contains(_item(4).text, "선행: 마을회관", "집 선행 미충족 사유 표기")

func test_house_active_at_town_hall_tier() -> void:
	menu.open(_center("town_hall"))  # 마을회관 티어
	menu._on_build_pressed()
	assert_false(_item(0).disabled, "마을회관 티어에서 농장 활성")
	assert_false(_item(4).disabled, "마을회관 티어에서 집 활성")

func test_item_disabled_when_poor() -> void:
	_join_poor_territory()  # 캠프는 있으나 자원 0
	menu.open(building)
	menu._on_build_pressed()
	assert_true(_item(0).disabled, "자원 부족하면 농장(선행 충족)도 비활성")

func test_item_disabled_without_territory() -> void:
	menu.open(building)  # 영지 없음
	menu._on_build_pressed()
	assert_true(_item(0).disabled, "영지 없으면 항목 비활성")

func test_selecting_item_emits_signal() -> void:
	var t := _join_territory()
	menu.open(building)
	menu._on_build_pressed()
	watch_signals(menu)
	_item(0).pressed.emit()  # 농장(활성)
	assert_signal_emitted_with_parameters(menu, "build_selected", ["farm", t])

func test_reopen_resets_to_info_view() -> void:
	_join_territory()
	menu.open(building)
	menu._on_build_pressed()
	assert_true(menu._build_list.visible, "건축으로 리스트 열림")
	menu.open(building)
	assert_false(menu._build_list.visible, "재오픈 시 리스트 숨김")
	assert_true(menu._build_btn.visible, "재오픈 시 건축 버튼 표시")

# --- 거점 업그레이드 버튼 ---

func test_upgrade_button_shown_for_camp() -> void:
	# 마을회관 비용 목재20·식량20 충분.
	menu.open(_center("camp", {"목재": 30, "식량": 30}))
	assert_true(menu._upgrade_btn.visible, "캠프는 다음 티어(마을회관) 있어 업그레이드 버튼 표시")
	assert_string_contains(menu._upgrade_btn.text, "마을회관", "다음 티어 라벨 표시")
	assert_false(menu._upgrade_btn.disabled, "마을회관 비용 충분 → 활성")

func test_upgrade_button_hidden_for_castle() -> void:
	menu.open(_center("castle"))
	assert_false(menu._upgrade_btn.visible, "성은 최종 티어라 업그레이드 버튼 숨김")

func test_upgrade_button_disabled_when_poor() -> void:
	menu.open(_center("camp", {}))  # 자원 0
	assert_true(menu._upgrade_btn.visible, "다음 티어 있으니 표시")
	assert_true(menu._upgrade_btn.disabled, "비용 부족이면 비활성")

func test_upgrade_button_emits_signal() -> void:
	var c := _center("camp")
	menu.open(c)
	watch_signals(menu)
	menu._upgrade_btn.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "upgrade_requested", [c])

# --- 성벽 건설 버튼 ---

func test_wall_button_shown_for_town_hall() -> void:
	menu.open(_center("town_hall", {"목재": 20, "철": 20}))
	assert_true(menu._wall_btn.visible, "마을회관 + 자재 충분 → 성벽 건설 버튼 표시")
	assert_string_contains(menu._wall_btn.text, "성벽 건설", "성벽 건설 텍스트")
	assert_false(menu._wall_btn.disabled, "자재 충분 → 활성")

func test_wall_button_hidden_for_camp() -> void:
	menu.open(_center("camp"))
	assert_false(menu._wall_btn.visible, "캠프(tier 0)는 성벽 불가 → 숨김")

func test_wall_button_hidden_when_already_walled() -> void:
	var c := _center("town_hall", {"목재": 20, "철": 20})
	c.wall_level = 1
	menu.open(c)
	assert_false(menu._wall_btn.visible, "이미 성벽 → 숨김")

func test_wall_button_disabled_when_poor() -> void:
	menu.open(_center("town_hall", {"목재": 5}))
	assert_true(menu._wall_btn.visible, "마을회관이라 표시")
	assert_true(menu._wall_btn.disabled, "자재 부족(철 없음) → 비활성")

func test_wall_button_emits_signal() -> void:
	var c := _center("town_hall", {"목재": 20, "철": 20})
	menu.open(c)
	watch_signals(menu)
	menu._wall_btn.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "wall_requested", [c], "성벽 건설 버튼 → wall_requested(building)")

# --- 캠프 건설 (새 영지) 버튼 ---

func test_found_camp_button_active_when_affordable() -> void:
	menu.open(_center("town_hall"))  # RES: 목재40·식량50 → 캠프 비용 목재10·식량10 감당
	assert_true(menu._found_camp_btn.visible, "캠프 건설 버튼 표시")
	assert_string_contains(menu._found_camp_btn.text, "캠프 건설", "라벨 표시")
	assert_false(menu._found_camp_btn.disabled, "비용 충분 → 활성")

func test_found_camp_button_disabled_when_poor() -> void:
	menu.open(_center("town_hall", {}))  # 자원 0
	assert_true(menu._found_camp_btn.disabled, "비용 부족이면 비활성")

func test_found_camp_button_emits_signal() -> void:
	var c := _center("town_hall")
	var t = c.territory
	menu.open(c)
	watch_signals(menu)
	menu._found_camp_btn.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "found_camp_requested", [t])

# --- 캠프 철거 버튼 ---

func test_demolish_button_shown_when_can() -> void:
	menu.open(_center("camp"), null, true)
	assert_true(menu._demolish_btn.visible, "can_demolish=true → 철거 버튼 표시")

func test_demolish_button_hidden_by_default() -> void:
	menu.open(_center("camp"))   # 기본 can_demolish=false
	assert_false(menu._demolish_btn.visible, "기본은 철거 버튼 숨김")

func test_demolish_button_toggle_on_reopen() -> void:
	menu.open(_center("camp"), null, true)
	menu.open(_center("camp"), null, false)
	assert_false(menu._demolish_btn.visible, "false로 재오픈 → 숨김(토글)")

func test_demolish_button_emits_signal() -> void:
	var c := _center("camp")
	menu.open(c, null, true)
	watch_signals(menu)
	menu._demolish_btn.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "demolish_requested", [c], "철거 버튼 → demolish_requested(building)")

# --- 부대 헬퍼 ---

func _party_with(n: int) -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	for i in n:
		p.add_member(load("res://scenes/human/human.gd").new("병사%d" % i))
	if n > 0:
		p.commander = p.members[0]
	return p

# --- 투석기·충차 생산 (_siege_btn / _ram_btn) → docs/spec/features/siege-engines.md ---

## 거점 + 그 영지에 완성된 공성 작업장을 둔 거점을 반환한다.
func _center_with_workshop(res := RES) -> Node2D:
	var c := _center("town_hall", res)
	var w = load("res://scenes/building/building.gd").new()
	add_child_autofree(w)
	w.setup(terrain, Vector2i(24, 24), "siege_workshop")   # 완성
	c.territory.add_building(w)
	return c

func test_siege_button_shown_when_workshop_and_party() -> void:
	var c := _center_with_workshop({"금": 100, "목재": 50, "철": 50})
	menu.open(c, _party_with(4))
	assert_true(menu._siege_btn.visible, "완성 작업장 + 주둔 부대 + 자원 충분 → 표시")
	assert_string_contains(menu._siege_btn.text, "투석기", "투석기 생산 텍스트")
	assert_false(menu._siege_btn.disabled, "자원 충분 → 활성")

func test_siege_button_hidden_without_workshop() -> void:
	var c := _center("town_hall", {"금": 100, "목재": 50, "철": 50})
	menu.open(c, _party_with(4))
	assert_false(menu._siege_btn.visible, "작업장 없으면 숨김")

func test_siege_button_hidden_without_party() -> void:
	var c := _center_with_workshop({"금": 100, "목재": 50, "철": 50})
	menu.open(c)   # 주둔 부대 없음
	assert_false(menu._siege_btn.visible, "주둔 부대 없으면 숨김")

func test_siege_button_disabled_when_poor() -> void:
	var c := _center_with_workshop({"금": 10})   # 자원 부족
	menu.open(c, _party_with(4))
	assert_true(menu._siege_btn.visible, "작업장 + 부대라 표시")
	assert_true(menu._siege_btn.disabled, "자원 부족 → 비활성")

func test_siege_button_emits_signal() -> void:
	var c := _center_with_workshop({"금": 100, "목재": 50, "철": 50})
	menu.open(c, _party_with(4))
	watch_signals(menu)
	menu._siege_btn.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "siege_produced", [c, "catapult"], "투석기 버튼 → siege_produced(building, \"catapult\")")

func test_ram_button_shown_when_workshop_and_party() -> void:
	var c := _center_with_workshop({"금": 100, "목재": 50, "철": 50})
	menu.open(c, _party_with(4))
	assert_true(menu._ram_btn.visible, "완성 작업장 + 주둔 부대 + 자원 충분 → 표시")
	assert_string_contains(menu._ram_btn.text, "충차", "충차 생산 텍스트")
	assert_false(menu._ram_btn.disabled, "자원 충분 → 활성")

func test_ram_button_hidden_without_workshop() -> void:
	var c := _center("town_hall", {"금": 100, "목재": 50, "철": 50})
	menu.open(c, _party_with(4))
	assert_false(menu._ram_btn.visible, "작업장 없으면 숨김")

func test_ram_button_disabled_when_poor() -> void:
	var c := _center_with_workshop({"금": 10})   # 자원 부족
	menu.open(c, _party_with(4))
	assert_true(menu._ram_btn.visible, "작업장 + 부대라 표시")
	assert_true(menu._ram_btn.disabled, "자원 부족 → 비활성")

func test_ram_button_emits_signal() -> void:
	var c := _center_with_workshop({"금": 100, "목재": 50, "철": 50})
	menu.open(c, _party_with(4))
	watch_signals(menu)
	menu._ram_btn.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "siege_produced", [c, "battering_ram"], "충차 버튼 → siege_produced(building, \"battering_ram\")")
