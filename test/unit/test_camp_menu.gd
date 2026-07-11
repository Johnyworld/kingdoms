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

func test_build_list_four_items_quarry_active() -> void:
	menu.open(_center("camp"))  # 캠프 티어
	menu._on_build_pressed()
	assert_true(menu._build_list.visible, "건축 후 리스트 표시")
	assert_eq(menu._build_list.get_child_count(), 4, "건축 가능 4종(거점 제외)")
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

# --- 수비대 편성 ---

func _party_with(n: int) -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	for i in n:
		p.add_member(load("res://scenes/human/human.gd").new("병사%d" % i))
	if n > 0:
		p.commander = p.members[0]
	return p

func _soldier() -> Object:
	return load("res://scenes/human/human.gd").new("수비병")

func test_garrison_panel_shown_with_party() -> void:
	_join_territory()
	building.garrison = [_soldier(), _soldier()]
	menu.open(building, _party_with(3))
	assert_true(menu._garrison_panel.visible, "부대 있으면 편성 패널 표시")
	assert_eq(menu._party_list.get_child_count(), 3, "부대 목록 3명")
	assert_eq(menu._garrison_list.get_child_count(), 2, "수비대 목록 2명")

func test_garrison_panel_hidden_without_party() -> void:
	_join_territory()
	menu.open(building)
	assert_false(menu._garrison_panel.visible, "부대 없으면 편성 패널 숨김")

func test_garrison_panel_shown_for_town_hall_center() -> void:
	# 거점은 캠프뿐 아니라 마을회관·성도 포함 — 마을회관 거점도 수비대 편성 패널이 뜬다.
	var hall = load("res://scenes/building/building.gd").new()
	add_child_autofree(hall)
	hall.setup(terrain, Vector2i(28, 28), "town_hall")
	var t = load("res://scenes/territory/territory.gd").new("파리", RES.duplicate(true))
	t.add_building(hall)
	menu.open(hall, _party_with(2))
	assert_true(menu._garrison_panel.visible, "마을회관(거점)도 편성 패널 표시")

func test_garrison_panel_hidden_for_non_center() -> void:
	# 농장(거점 아님)은 편성 패널 안 뜸.
	var farm = load("res://scenes/building/building.gd").new()
	add_child_autofree(farm)
	farm.setup(terrain, Vector2i(28, 28), "farm")
	var t = load("res://scenes/territory/territory.gd").new("파리", RES.duplicate(true))
	t.add_building(farm)
	menu.open(farm, _party_with(2))
	assert_false(menu._garrison_panel.visible, "농장(거점 아님)은 편성 패널 숨김")

func test_move_member_to_garrison() -> void:
	_join_territory()
	building.garrison = []
	var p := _party_with(2)
	var h = p.members[0]
	menu.open(building, p)
	menu._member_to_garrison(h)
	assert_false(h in p.members, "부대에서 빠짐")
	assert_true(h in building.garrison, "수비대에 들어감")

func test_move_member_to_party() -> void:
	_join_territory()
	var sol := _soldier()
	building.garrison = [sol]
	var p := _party_with(1)
	menu.open(building, p)
	menu._member_to_party(sol)
	assert_true(sol in p.members, "부대로 들어감")
	assert_false(sol in building.garrison, "수비대에서 빠짐")

func test_move_emits_garrison_changed() -> void:
	_join_territory()
	var p := _party_with(2)
	menu.open(building, p)
	watch_signals(menu)
	menu._member_to_garrison(p.members[0])
	assert_signal_emitted(menu, "garrison_changed", "편성 이동 시 방출")

# --- 새 부대 편성 ---

func _raise_button() -> Button:
	# 편성 패널 vbox의 마지막 자식이 "새 부대 편성" 버튼.
	var vbox = menu._garrison_panel.get_child(0)
	return vbox.get_child(vbox.get_child_count() - 1) as Button

func test_raise_button_present() -> void:
	_join_territory()
	menu.open(building, _party_with(1))
	assert_eq(_raise_button().text, "새 부대 편성", "편성 패널에 새 부대 편성 버튼")

func test_raise_button_emits_signal() -> void:
	_join_territory()
	menu.open(building, _party_with(1))
	watch_signals(menu)
	_raise_button().pressed.emit()
	assert_signal_emitted_with_parameters(menu, "raise_party", [building], "버튼 클릭 → raise_party(building)")

func test_party_button_press_moves_member() -> void:
	# 버튼 pressed 시그널 경로(실제 클릭)로 이동 — 시그널 처리 중 리스트 재구성이 안전해야 한다(locked 방지).
	_join_territory()
	building.garrison = []
	var p := _party_with(2)
	var h = p.members[0]
	menu.open(building, p)
	(menu._party_list.get_child(0) as Button).pressed.emit()
	assert_true(h in building.garrison, "부대 버튼 클릭 → 수비대로 이동")
	assert_false(h in p.members, "부대에서 빠짐")
