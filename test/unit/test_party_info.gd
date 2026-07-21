extends GutTest
## 부대 정보 패널 — 부대 클릭 시 우측 상단에 이름·이동력·시야·지휘관·병력을 표시(순수 class+count).

var panel: CanvasLayer

func before_each() -> void:
	panel = load("res://scenes/party/party_info.gd").new()
	add_child_autofree(panel)

func _party(soldiers := 2, cmdr := "경보병") -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.party_name = "주인공 부대"
	p.kind = p.KIND_TROOP
	p.troop_type = "light_infantry"   # 이동력·시야는 클래스 기반 → game_units.gd
	p.soldiers = soldiers
	p.commander_name = cmdr
	return p

func test_shows_party_name() -> void:
	panel.open(_party())
	assert_eq(panel._title.text, "주인공 부대", "제목 라벨 = 부대 이름")

func test_shows_faction_name() -> void:
	var p := _party()
	p.faction_name = "푸른 왕국"
	panel.open(p)
	assert_eq(panel._faction.text, "푸른 왕국", "세력 라벨 = 부대 세력명")
	assert_true(panel._faction.visible, "세력명이 있으면 세력 라벨 표시")

func test_hides_faction_when_empty() -> void:
	panel.open(_party())  # faction_name 기본 ""
	assert_false(panel._faction.visible, "세력명이 비면 세력 라벨 숨김")

func test_summary_shows_movement_and_vision() -> void:
	panel.open(_party())
	var expected := "이동력 %d · 시야 %d · 사거리 근접" % [GameUnits.movement("light_infantry"), GameUnits.vision("light_infantry")]
	assert_eq(panel._summary.text, expected, "요약 = 클래스 이동력·시야·사거리(근접)")

func test_shows_commander_and_soldiers() -> void:
	panel.open(_party(7, "경보병"))
	var text: String = (panel._member_list.get_child(0) as Label).text
	assert_string_contains(text, "경보병", "지휘관 이름 표시")
	assert_string_contains(text, "7", "병력수 표시")

func test_summary_class_based_regardless_of_soldiers() -> void:
	# 스탯은 클래스 기반이라 병력수와 무관(병력 0이어도 클래스 이동력·시야).
	panel.open(_party(0))
	var expected := "이동력 %d · 시야 %d · 사거리 근접" % [GameUnits.movement("light_infantry"), GameUnits.vision("light_infantry")]
	assert_eq(panel._summary.text, expected, "스탯은 클래스 기반(병력 없어도 클래스값)")

func test_reopen_replaces_line() -> void:
	panel.open(_party(5, "경보병"))
	panel.open(_party(3, "경궁병"))
	assert_eq(panel._member_list.get_child_count(), 1, "재오픈 시 한 줄로 교체")
	assert_string_contains((panel._member_list.get_child(0) as Label).text, "경궁병", "새 부대 정보로 교체")

func test_open_shows_close_hides() -> void:
	panel.open(_party())
	assert_true(panel.visible, "open 후 표시")
	panel.close()
	assert_false(panel.visible, "close 후 숨김")
