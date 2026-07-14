extends GutTest
## 부대 분할 패널(SplitPanel) — 원 부대 / 새 부대 두 목록, 멤버를 양쪽으로 이동.
## 원 부대 ↔ 새 부대 두 목록 전송 패턴.

var panel: CanvasLayer

func before_each() -> void:
	panel = load("res://scenes/party/split_panel.gd").new()
	add_child_autofree(panel)

func _party_with(n: int) -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	for i in n:
		p.add_member(load("res://scenes/human/human.gd").new("병사%d" % i))
	return p

func test_hidden_at_start() -> void:
	assert_false(panel.visible, "생성 직후 숨김")

func test_open_populates_lists() -> void:
	panel.open(_party_with(3), _party_with(0))
	assert_true(panel.visible, "open 후 표시")
	assert_eq(panel._orig_list.get_child_count(), 3, "원 부대 목록 3명")
	assert_eq(panel._new_list.get_child_count(), 0, "새 부대 목록 0명")

func test_move_to_new() -> void:
	var orig := _party_with(2)
	var newp := _party_with(0)
	var h = orig.members[0]
	panel.open(orig, newp)
	panel._to_new(h)
	assert_false(h in orig.members, "원 부대에서 빠짐")
	assert_true(h in newp.members, "새 부대에 들어감")

func test_move_to_orig() -> void:
	var orig := _party_with(1)
	var newp := _party_with(1)
	var h = newp.members[0]
	panel.open(orig, newp)
	panel._to_orig(h)
	assert_true(h in orig.members, "원 부대로 돌아옴")
	assert_false(h in newp.members, "새 부대에서 빠짐")

func test_move_emits_changed() -> void:
	var orig := _party_with(2)
	var newp := _party_with(0)
	panel.open(orig, newp)
	watch_signals(panel)
	panel._to_new(orig.members[0])
	assert_signal_emitted(panel, "changed", "멤버 이동 시 changed 방출")

func test_button_press_moves_member() -> void:
	# 버튼 pressed 시그널 경로(리스트 재구성 중 free "locked" 방지 확인).
	var orig := _party_with(2)
	var newp := _party_with(0)
	var h = orig.members[0]
	panel.open(orig, newp)
	(panel._orig_list.get_child(0) as Button).pressed.emit()
	assert_true(h in newp.members, "버튼 클릭 → 새 부대로 이동")

# --- 노획 장비 분배 ---

func test_loot_section_and_transfer() -> void:
	var orig := _party_with(2)
	var newp := _party_with(0)
	orig.loot_items = ["sword", "bow"]
	panel.open(orig, newp)
	assert_gt(panel._loot_list.get_child_count(), 0, "노획 장비 있으면 장비 행 표시")
	panel._loot_to_new("sword")   # 1개씩
	assert_false("sword" in orig.loot_items, "원 부대에서 sword 빠짐")
	assert_true("sword" in newp.loot_items, "새 부대에 sword")
