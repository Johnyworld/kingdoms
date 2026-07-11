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

func test_population_row_shows_cap() -> void:
	_join_territory()  # 캠프(상한 10) 편입, RES 인구 10
	menu.open(building)
	# 인구가 자원 삽입 순서상 첫 항목 → 이름 child(0), 값 child(1).
	assert_eq((menu._res_grid.get_child(0) as Label).text, "인구", "첫 행은 인구")
	assert_eq((menu._res_grid.get_child(1) as Label).text, "10 / 10", "인구 값은 현재/상한")

# --- 건축 리스트 (2a) + 선행건물 게이트 ---
# BUILDABLE_IDS 순서 = [town_hall(0), quarry(1), farm(2), house(3), lumberjack(4), castle(5)].

func _item(idx: int) -> Button:
	return menu._build_list.get_child(idx) as Button

## 영지에 완성 마을회관을 편입한다(농장·집·벌목소 선행 해금용).
func _add_town_hall(t) -> void:
	var hall = load("res://scenes/building/building.gd").new()
	add_child_autofree(hall)
	hall.setup(terrain, Vector2i(35, 35), "town_hall")  # 완성
	t.add_building(hall)

func test_build_opens_list_with_items() -> void:
	_join_territory()  # 자원 충분 + 완성 캠프 편입됨
	menu.open(building)
	menu._on_build_pressed()
	assert_true(menu._build_list.visible, "건축 후 리스트 표시")
	assert_eq(menu._build_list.get_child_count(), 6, "건축 가능 6종")
	# 채석장(선행 camp, 목재10 ≤ 보유 20) 활성.
	assert_false(_item(1).disabled, "채석장은 시작부터 활성(선행 camp)")

func test_castle_locked_without_town_hall() -> void:
	_join_territory()  # 캠프만 완성, 마을회관 없음
	menu.open(building)
	menu._on_build_pressed()
	assert_true(_item(5).disabled, "마을회관 없으면 성 비활성")
	assert_string_contains(_item(5).text, "선행: 마을회관", "성 선행 미충족 사유 표기")

func test_item_text_has_label_and_cost() -> void:
	_join_territory()
	menu.open(building)
	menu._on_build_pressed()
	var text := _item(1).text  # 채석장
	assert_string_contains(text, "채석장", "항목에 라벨 포함")
	assert_string_contains(text, "목재", "항목에 비용(목재) 포함")

func test_farm_locked_without_town_hall() -> void:
	_join_territory()  # 캠프만 완성, 마을회관 없음
	menu.open(building)
	menu._on_build_pressed()
	assert_true(_item(2).disabled, "마을회관 없으면 농장 비활성")
	assert_string_contains(_item(2).text, "선행: 마을회관", "선행 미충족 사유 표기")

func test_farm_active_after_town_hall() -> void:
	var t := _join_territory()
	_add_town_hall(t)
	menu.open(building)
	menu._on_build_pressed()
	assert_false(_item(2).disabled, "마을회관 완성 후 농장 활성")

func test_item_disabled_when_poor() -> void:
	_join_poor_territory()  # 캠프는 있으나 자원 0
	menu.open(building)
	menu._on_build_pressed()
	assert_true(_item(1).disabled, "자원 부족하면 채석장(선행 충족)도 비활성")

func test_item_disabled_without_territory() -> void:
	menu.open(building)  # 영지 없음
	menu._on_build_pressed()
	assert_true(_item(1).disabled, "영지 없으면 항목 비활성")

func test_selecting_item_emits_signal() -> void:
	var t := _join_territory()
	menu.open(building)
	menu._on_build_pressed()
	watch_signals(menu)
	_item(1).pressed.emit()  # 채석장(활성)
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
