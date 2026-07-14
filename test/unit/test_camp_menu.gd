extends GutTest
## 캠프 메뉴 UI — 클릭한 건물의 영지 정보(이름/세력/자원) 표시.

const BLUE := Color(0.2, 0.3, 0.8)
const RES := {"인구": 10, "밀": 50, "빵": 20, "나무": 20, "목재": 20, "철": 10, "철괴": 10}

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
	# 세력 있는 영지로 한 번 연 뒤, 영지 없는 건물로 다시 열면 색상 오버라이드가 남지 않아야 한다.
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
	# 자원 7종 × 2열(이름/값) = 14개 자식.
	assert_eq(menu._res_grid.get_child_count(), 14, "자원 그리드가 영지 자원 7종으로 채워진다")

## 지정 거점 티어 건물 + 자원 영지를 만들어 그 거점을 반환한다(첫 거점은 마을회관 티어).
func _center(type_id: String, res := RES) -> Node2D:
	var b = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.setup(terrain, Vector2i(20, 20), type_id)
	var t = load("res://scenes/territory/territory.gd").new("파리", res.duplicate(true))
	t.add_building(b)
	return b

func test_population_row_shows_cap() -> void:
	# 마을회관 거점(상한 10) + 인구 10 → "10 / 10".
	menu.open(_center("town_hall"))
	assert_eq((menu._res_grid.get_child(0) as Label).text, "인구", "첫 행은 인구")
	assert_eq((menu._res_grid.get_child(1) as Label).text, "10 / 10", "인구 값은 현재/상한")

# --- 건축 리스트 + 선행 티어 게이트. BUILDABLE 순서 = [quarry(0), farm(1), house(2), lumberjack(3)]. ---

func _item(idx: int) -> Button:
	return menu._build_list.get_child(idx) as Button

func test_build_list_five_items_quarry_active() -> void:
	menu.open(_center("camp"))  # 캠프 티어
	menu._on_build_pressed()
	assert_true(menu._build_list.visible, "건축 후 리스트 표시")
	assert_eq(menu._build_list.get_child_count(), 5, "건축 가능 5종(거점 제외, 공성 작업장 포함)")
	assert_false(_item(0).disabled, "채석장(선행 camp)은 캠프 티어부터 활성")

func test_item_text_has_label_and_cost() -> void:
	menu.open(_center("camp"))
	menu._on_build_pressed()
	var text := _item(0).text  # 채석장
	assert_string_contains(text, "채석장", "항목에 라벨 포함")
	assert_string_contains(text, "목재", "항목에 비용(목재) 포함")
	assert_string_contains(text, "인원 1", "항목에 필요인원 표시")

func test_item_disabled_when_low_population() -> void:
	menu.open(_center("camp", {"인구": 0, "목재": 20}))  # 선행·자재 OK, 인구 0 < 1
	menu._on_build_pressed()
	assert_true(_item(0).disabled, "인구 부족(0 < 1)이면 채석장 비활성")

func test_farm_locked_at_camp_tier() -> void:
	menu.open(_center("camp"))  # 캠프 티어(마을회관 미만)
	menu._on_build_pressed()
	assert_true(_item(1).disabled, "캠프 티어면 농장 비활성")
	assert_string_contains(_item(1).text, "선행: 마을회관", "선행 미충족 사유 표기")

func test_farm_active_at_town_hall_tier() -> void:
	menu.open(_center("town_hall"))  # 마을회관 티어
	menu._on_build_pressed()
	assert_false(_item(1).disabled, "마을회관 티어면 농장 활성")

# --- 거점 업그레이드 버튼 ---

func test_upgrade_button_shown_for_camp() -> void:
	# 마을회관 비용 목재10·석재10·밀20 충분한 자원(RES엔 석재가 없어 명시).
	menu.open(_center("camp", {"목재": 20, "석재": 20, "밀": 50}))
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
	menu.open(_center("town_hall", {"목재": 20, "석재": 20}))
	assert_true(menu._wall_btn.visible, "마을회관 + 자재 충분 → 성벽 건설 버튼 표시")
	assert_string_contains(menu._wall_btn.text, "성벽 건설", "성벽 건설 텍스트")
	assert_false(menu._wall_btn.disabled, "자재 충분 → 활성")

func test_wall_button_hidden_for_camp() -> void:
	menu.open(_center("camp"))
	assert_false(menu._wall_btn.visible, "캠프(tier 0)는 성벽 불가 → 숨김")

func test_wall_button_hidden_when_already_walled() -> void:
	var c := _center("town_hall", {"목재": 20, "석재": 20})
	c.wall_level = 1
	menu.open(c)
	assert_false(menu._wall_btn.visible, "이미 성벽 → 숨김")

func test_wall_button_disabled_when_poor() -> void:
	menu.open(_center("town_hall", {"목재": 5}))
	assert_true(menu._wall_btn.visible, "마을회관이라 표시")
	assert_true(menu._wall_btn.disabled, "자재 부족(석재 없음) → 비활성")

func test_wall_button_emits_signal() -> void:
	var c := _center("town_hall", {"목재": 20, "석재": 20})
	menu.open(c)
	watch_signals(menu)
	menu._wall_btn.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "wall_requested", [c], "성벽 건설 버튼 → wall_requested(building)")

# --- 캠프 건설 (새 영지) 버튼 ---

func test_found_camp_button_active_when_affordable() -> void:
	menu.open(_center("town_hall"))  # RES: 목재20·밀50 → 캠프 비용 목재10·밀10 감당
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

# --- 보급(화물) 적재/하역 ---

func test_cargo_panel_shown_with_party() -> void:
	menu.open(_center("town_hall"), _party_with(1))
	assert_true(menu._cargo_panel.visible, "부대 + 거점이면 보급 패널 표시")

func test_cargo_panel_hidden_without_party() -> void:
	menu.open(_center("town_hall"))
	assert_false(menu._cargo_panel.visible, "부대 없으면 보급 패널 숨김")

func test_load_cargo_moves_resource_to_party() -> void:
	var c := _center("town_hall")  # RES: 목재 20
	var p := _party_with(1)
	menu.open(c, p)
	menu._load_cargo("목재")
	assert_eq(c.territory.resources["목재"], 15, "영지 목재 20 → 15(-5)")
	assert_eq(p.cargo.get("목재", 0), 5, "부대 화물 목재 +5")

func test_unload_cargo_moves_resource_to_territory() -> void:
	var c := _center("town_hall", {"목재": 0})
	var p := _party_with(1)
	p.add_cargo("목재", 10)
	menu.open(c, p)
	menu._unload_cargo("목재")
	assert_eq(p.cargo.get("목재", 0), 5, "부대 화물 10 → 5(-5)")
	assert_eq(c.territory.resources.get("목재", 0), 5, "영지 목재 +5")

func test_cargo_panel_excludes_population() -> void:
	menu.open(_center("town_hall"), _party_with(1))  # RES에 인구 포함
	var has_pop := false
	for row in menu._cargo_list.get_children():
		if (row.get_child(0) as Label).text.begins_with("인구"):
			has_pop = true
	assert_false(has_pop, "보급 패널에 인구 행 없음(노동력)")

# --- 판매 (장비·화물 → 영지 금) ---

func test_sell_panel_shown_with_party() -> void:
	menu.open(_center("town_hall"), _party_with(1))
	assert_true(menu._sell_panel.visible, "부대 + 거점이면 판매 패널 표시")

func test_sell_panel_hidden_without_party() -> void:
	menu.open(_center("town_hall"))
	assert_false(menu._sell_panel.visible, "부대 없으면 판매 패널 숨김")

func test_sell_item_adds_gold() -> void:
	var c := _center("town_hall")
	var p := _party_with(1)
	p.loot_items = ["sword"]
	menu.open(c, p)
	menu._sell_item("sword")
	assert_eq(c.territory.resources.get("금", 0), 14, "영지 금 +14(검 가치)")
	assert_false("sword" in p.loot_items, "노획 장비에서 제거")

func test_sell_cargo_adds_gold() -> void:
	var c := _center("town_hall")
	var p := _party_with(1)
	p.add_cargo("철괴", 10)
	menu.open(c, p)
	menu._sell_cargo("철괴")   # CARGO_STEP(5)씩
	assert_eq(c.territory.resources.get("금", 0), 60, "영지 금 +60(12×5)")
	assert_eq(p.cargo.get("철괴", 0), 5, "화물 철괴 10 → 5")

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

# --- 자원 구매 / 병사 구매 ---

func test_buy_resource_adds_to_territory() -> void:
	var c := _center("town_hall", {"금": 30})
	menu.open(c, _party_with(1))
	menu._buy_resource("밀")   # 구매가 1×2×5 = 10, 5개 매입
	assert_eq(c.territory.resources.get("금", 0), 20, "영지 금 30 → 20(-10)")
	assert_eq(c.territory.resources.get("밀", 0), 5, "영지 밀 +5")

func test_buy_resource_no_op_when_poor() -> void:
	var c := _center("town_hall", {"금": 5})
	menu.open(c, _party_with(1))
	menu._buy_resource("밀")   # 10 필요, 5뿐
	assert_eq(c.territory.resources.get("금", 0), 5, "금 변화 없음")
	assert_eq(c.territory.resources.get("밀", 0), 0, "밀 변화 없음")

func test_buy_soldier_joins_stationed_party() -> void:
	var c := _center("town_hall", {"금": 30, "인구": 5})
	var p := _party_with(1)
	menu.open(c, p)
	menu._buy_soldier()
	assert_eq(c.territory.resources.get("금", 0), 10, "금 30 → 10(-20)")
	assert_eq(c.territory.resources.get("인구", 0), 4, "인구 5 → 4(-1)")
	assert_eq(p.members.size(), 2, "주둔 부대에 소집병 +1(1→2)")

func test_buy_soldier_no_op_when_poor() -> void:
	var c := _center("town_hall", {"금": 10, "인구": 5})   # 금 부족
	var p := _party_with(1)
	menu.open(c, p)
	menu._buy_soldier()
	assert_eq(c.territory.resources.get("금", 0), 10, "금 부족 → 변화 없음")
	assert_eq(p.members.size(), 1, "부대 변화 없음")

func test_buy_soldier_no_op_when_no_pop() -> void:
	var c := _center("town_hall", {"금": 30, "인구": 0})   # 인구 부족
	var p := _party_with(1)
	menu.open(c, p)
	menu._buy_soldier()
	assert_eq(c.territory.resources.get("금", 0), 30, "인구 부족 → 금 변화 없음")
	assert_eq(p.members.size(), 1, "부대 변화 없음")

func test_buy_soldier_no_op_without_party() -> void:
	var c := _center("town_hall", {"금": 30, "인구": 5})
	menu.open(c)   # 주둔 부대 없음
	menu._buy_soldier()
	assert_eq(c.territory.resources.get("금", 0), 30, "주둔 부대 없으면 no-op")

func test_sell_cargo_excludes_pop_and_gold() -> void:
	var c := _center("town_hall")
	var p := _party_with(1)
	p.add_cargo("철괴", 10)
	p.cargo["인구"] = 5   # 인위적으로 넣어도
	p.cargo["금"] = 5     # 판매 목록에 안 뜬다
	menu.open(c, p)
	for row in menu._sell_cargo_list.get_children():
		var t: String = (row.get_child(0) as Label).text
		assert_false(t.begins_with("인구"), "판매 화물에 인구 없음")
		assert_false(t.begins_with("금"), "판매 화물에 금 없음")

# --- 구매 (금 → 장비) ---

func _buy_button(id: String) -> Button:
	# 구매 목록에서 그 아이템 행의 [구매] 버튼을 찾는다(섹션 헤더 Label은 건너뛰고 HBox 행만).
	var want := ItemTypes.item_name(id)
	for row in menu._buy_list.get_children():
		if not (row is HBoxContainer):
			continue
		if (row.get_child(0) as Label).text.begins_with(want):
			return row.get_child(1) as Button
	return null

func test_buy_panel_shown_with_party() -> void:
	menu.open(_center("town_hall"), _party_with(1))
	assert_true(menu._buy_panel.visible, "부대 + 거점이면 구매 패널 표시")

func test_buy_panel_hidden_without_party() -> void:
	menu.open(_center("town_hall"))
	assert_false(menu._buy_panel.visible, "부대 없으면 구매 패널 숨김")

func test_buy_item_spends_gold() -> void:
	var c := _center("town_hall", {"금": 30})
	var p := _party_with(1)
	menu.open(c, p)
	menu._buy_item("sword")   # 구매가 14×2=28
	assert_eq(c.territory.resources.get("금", 0), 2, "영지 금 30 → 2(-28)")
	assert_true("sword" in p.loot_items, "부대 노획 장비에 sword")

func test_buy_tool_grapple_ladder() -> void:
	var c := _center("town_hall", {"금": 30})
	var p := _party_with(1)
	menu.open(c, p)
	menu._buy_item("grapple_ladder")   # 도구 구매가 12×2=24
	assert_eq(c.territory.resources.get("금", 0), 6, "영지 금 30 → 6(-24)")
	assert_true("grapple_ladder" in p.loot_items, "부대 loot_items에 고리 사다리")

func test_buy_disabled_when_poor() -> void:
	var c := _center("town_hall", {"금": 10})
	menu.open(c, _party_with(1))
	assert_true(_buy_button("sword").disabled, "금 10 < 28이면 [구매] 비활성")

func test_buy_no_op_when_poor() -> void:
	var c := _center("town_hall", {"금": 10})
	var p := _party_with(1)
	menu.open(c, p)
	menu._buy_item("sword")   # 금 부족
	assert_eq(c.territory.resources.get("금", 0), 10, "금 변화 없음")
	assert_false("sword" in p.loot_items, "장비 추가 안 됨")

func test_buy_valueless_item_no_op() -> void:
	# 가치 0(카탈로그에 없는) id는 구매가 0 → 금 넉넉해도 no-op(금 0 무한 구매 방지).
	var c := _center("town_hall", {"금": 100})
	var p := _party_with(1)
	menu.open(c, p)
	menu._buy_item("없는아이템")
	assert_eq(c.territory.resources.get("금", 0), 100, "금 변화 없음")
	assert_false("없는아이템" in p.loot_items, "장비 추가 안 됨")

func test_item_disabled_when_poor() -> void:
	_join_poor_territory()  # 캠프는 있으나 자원 0
	menu.open(building)
	menu._on_build_pressed()
	assert_true(_item(0).disabled, "자원 부족하면 채석장(선행 충족)도 비활성")

func test_item_disabled_without_territory() -> void:
	menu.open(building)  # 영지 없음
	menu._on_build_pressed()
	assert_true(_item(0).disabled, "영지 없으면 항목 비활성")

func test_selecting_item_emits_signal() -> void:
	var t := _join_territory()
	menu.open(building)
	menu._on_build_pressed()
	watch_signals(menu)
	_item(0).pressed.emit()  # 채석장(활성)
	assert_signal_emitted_with_parameters(menu, "build_selected", ["quarry", t])

func test_reopen_resets_to_info_view() -> void:
	_join_territory()
	menu.open(building)
	menu._on_build_pressed()
	assert_true(menu._build_list.visible, "건축으로 리스트 열림")
	menu.open(building)
	assert_false(menu._build_list.visible, "재오픈 시 리스트 숨김")
	assert_true(menu._build_btn.visible, "재오픈 시 건축 버튼 표시")

# --- 부대 헬퍼 ---

func _party_with(n: int) -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	for i in n:
		p.add_member(load("res://scenes/human/human.gd").new("병사%d" % i))
	if n > 0:
		p.commander = p.members[0]
	return p

# --- 투석기 생산 (_siege_btn) → docs/spec/features/siege-engines.md ---

## 거점 + 그 영지에 완성된 공성 작업장을 둔 거점을 반환한다.
func _center_with_workshop(res := RES) -> Node2D:
	var c := _center("town_hall", res)
	var w = load("res://scenes/building/building.gd").new()
	add_child_autofree(w)
	w.setup(terrain, Vector2i(24, 24), "siege_workshop")   # 완성
	c.territory.add_building(w)
	return c

func test_siege_button_shown_when_workshop_and_party() -> void:
	var c := _center_with_workshop({"금": 100, "목재": 50, "석재": 50, "인구": 5})
	menu.open(c, _party_with(4))
	assert_true(menu._siege_btn.visible, "완성 작업장 + 주둔 부대 + 자원 충분 → 표시")
	assert_string_contains(menu._siege_btn.text, "투석기", "투석기 생산 텍스트")
	assert_false(menu._siege_btn.disabled, "자원 충분 → 활성")

func test_siege_button_hidden_without_workshop() -> void:
	var c := _center("town_hall", {"금": 100, "목재": 50, "석재": 50})
	menu.open(c, _party_with(4))
	assert_false(menu._siege_btn.visible, "작업장 없으면 숨김")

func test_siege_button_hidden_without_party() -> void:
	var c := _center_with_workshop({"금": 100, "목재": 50, "석재": 50})
	menu.open(c)   # 주둔 부대 없음
	assert_false(menu._siege_btn.visible, "주둔 부대 없으면 숨김")

func test_siege_button_disabled_when_poor() -> void:
	var c := _center_with_workshop({"금": 10})   # 자원 부족
	menu.open(c, _party_with(4))
	assert_true(menu._siege_btn.visible, "작업장 + 부대라 표시")
	assert_true(menu._siege_btn.disabled, "자원 부족 → 비활성")

func test_siege_button_emits_signal() -> void:
	var c := _center_with_workshop({"금": 100, "목재": 50, "석재": 50})
	menu.open(c, _party_with(4))
	watch_signals(menu)
	menu._siege_btn.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "siege_produced", [c, "catapult"], "투석기 버튼 → siege_produced(building, \"catapult\")")

func test_ram_button_shown_when_workshop_and_party() -> void:
	var c := _center_with_workshop({"금": 100, "목재": 50, "석재": 50, "인구": 5})
	menu.open(c, _party_with(4))
	assert_true(menu._ram_btn.visible, "완성 작업장 + 주둔 부대 + 자원 충분 → 표시")
	assert_string_contains(menu._ram_btn.text, "충차", "충차 생산 텍스트")
	assert_false(menu._ram_btn.disabled, "자원 충분 → 활성")

func test_ram_button_hidden_without_workshop() -> void:
	var c := _center("town_hall", {"금": 100, "목재": 50, "석재": 50})
	menu.open(c, _party_with(4))
	assert_false(menu._ram_btn.visible, "작업장 없으면 숨김")

func test_ram_button_disabled_when_poor() -> void:
	var c := _center_with_workshop({"금": 10})   # 자원 부족
	menu.open(c, _party_with(4))
	assert_true(menu._ram_btn.visible, "작업장 + 부대라 표시")
	assert_true(menu._ram_btn.disabled, "자원 부족 → 비활성")

func test_ram_button_emits_signal() -> void:
	var c := _center_with_workshop({"금": 100, "목재": 50, "석재": 50})
	menu.open(c, _party_with(4))
	watch_signals(menu)
	menu._ram_btn.pressed.emit()
	assert_signal_emitted_with_parameters(menu, "siege_produced", [c, "battering_ram"], "충차 버튼 → siege_produced(building, \"battering_ram\")")
