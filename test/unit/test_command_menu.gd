extends GutTest
## [지휘] 메뉴(CommandMenu) — 영웅부대의 따라옴/직접명령·전투우선/전투회피 지속 설정 토글. → squad-stance.md

var menu

func before_each() -> void:
	menu = load("res://scenes/party/command_menu.gd").new()
	add_child_autofree(menu)

func _hero() -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.kind = p.KIND_HERO
	p.commander_name = "아젤"
	return p

func test_open_shows_toggles() -> void:
	menu.open(_hero())
	assert_true(menu.is_open(), "open 후 모달 열림")
	assert_not_null(menu._follow_btn, "[따라옴] 버튼")
	assert_not_null(menu._direct_btn, "[직접명령] 버튼")
	assert_not_null(menu._engage_btn, "[전투우선] 버튼")
	assert_not_null(menu._avoid_btn, "[전투회피] 버튼")

func test_current_side_disabled() -> void:
	menu.open(_hero())   # 기본 직접명령·전투회피
	assert_true(menu._direct_btn.disabled, "현재=직접명령 → [직접명령] 비활성(선택 표시)")
	assert_false(menu._follow_btn.disabled, "[따라옴]은 활성")
	assert_true(menu._avoid_btn.disabled, "현재=전투회피 → [전투회피] 비활성")
	assert_false(menu._engage_btn.disabled, "[전투우선]은 활성")

func test_follow_toggle_sets_and_emits() -> void:
	var h := _hero()
	menu.open(h)
	watch_signals(menu)
	menu._follow_btn.pressed.emit()
	assert_true(h.command_follow, "[따라옴] → command_follow true")
	assert_signal_emitted(menu, "changed")

func test_direct_toggle_clears() -> void:
	var h := _hero()
	h.command_follow = true
	menu.open(h)
	menu._direct_btn.pressed.emit()
	assert_false(h.command_follow, "[직접명령] → command_follow false")

func test_engage_toggle_sets_and_emits() -> void:
	var h := _hero()
	menu.open(h)
	watch_signals(menu)
	menu._engage_btn.pressed.emit()
	assert_true(h.command_engage, "[전투우선] → command_engage true")
	assert_signal_emitted(menu, "changed")

func test_avoid_toggle_clears() -> void:
	var h := _hero()
	h.command_engage = true
	menu.open(h)
	menu._avoid_btn.pressed.emit()
	assert_false(h.command_engage, "[전투회피] → command_engage false")
