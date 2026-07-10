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

# --- 건축 리스트 (2a) ---

func _farm_item() -> Button:
	return menu._build_list.get_child(0) as Button

func test_build_opens_list_with_farm() -> void:
	_join_territory()  # 자원 충분
	menu.open(building)
	menu._on_build_pressed()
	assert_true(menu._build_list.visible, "건축 후 리스트 표시")
	assert_gt(menu._build_list.get_child_count(), 0, "리스트에 항목 존재")
	assert_false(_farm_item().disabled, "자원 충분하면 농장 항목 활성")

func test_farm_item_text_has_label_and_cost() -> void:
	_join_territory()
	menu.open(building)
	menu._on_build_pressed()
	var text := _farm_item().text
	assert_string_contains(text, "농장", "항목에 라벨 포함")
	assert_string_contains(text, "목재", "항목에 비용(목재) 포함")

func test_farm_item_disabled_when_poor() -> void:
	_join_poor_territory()
	menu.open(building)
	menu._on_build_pressed()
	assert_true(_farm_item().disabled, "자원 부족하면 농장 항목 비활성")

func test_farm_item_disabled_without_territory() -> void:
	menu.open(building)  # 영지 없음
	menu._on_build_pressed()
	assert_true(_farm_item().disabled, "영지 없으면 농장 항목 비활성")

func test_selecting_farm_emits_signal() -> void:
	var t := _join_territory()
	menu.open(building)
	menu._on_build_pressed()
	watch_signals(menu)
	_farm_item().pressed.emit()
	assert_signal_emitted_with_parameters(menu, "build_selected", ["farm", t])

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
