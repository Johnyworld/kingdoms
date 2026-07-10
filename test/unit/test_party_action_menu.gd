extends GutTest
## 부대 행동 메뉴 버튼 구성(PartyActionMenu) — 노드 비의존 순수 로직.
## party_actions(moved, can_shoot_any): 중앙 메뉴 [사격][휴식/대기].
## enemy_actions(can_move_adj, can_melee, can_shoot): 적 팝업 [이동][공격][사격].

func _by_id(list: Array, id: String) -> Dictionary:
	for a in list:
		if a["id"] == id:
			return a
	return {}

# --- 중앙 메뉴 (party_actions) ---

func test_party_actions_shoot_enabled() -> void:
	var a := PartyActionMenu.party_actions(false, true)
	assert_true(_by_id(a, "shoot")["enabled"], "사격 가능 적 있으면 [사격] 활성")
	assert_eq(_by_id(a, "rest")["label"], "휴식", "이동 전이면 휴식")

func test_party_actions_shoot_disabled() -> void:
	var a := PartyActionMenu.party_actions(false, false)
	assert_false(_by_id(a, "shoot")["enabled"], "사격 대상 없으면 [사격] 비활성")

func test_party_actions_label_after_move() -> void:
	var a := PartyActionMenu.party_actions(true, false)
	assert_eq(_by_id(a, "rest")["label"], "대기", "이동 후면 대기")

# --- 적 팝업 (enemy_actions) ---

func test_enemy_actions_melee_only() -> void:
	var a := PartyActionMenu.enemy_actions(true, true, false)
	assert_true(_by_id(a, "move")["enabled"], "인접 도달 가능 → [이동] 활성")
	assert_true(_by_id(a, "attack")["enabled"], "근접 가능 → [공격] 활성")
	assert_false(_by_id(a, "shoot")["enabled"], "사거리 밖 → [사격] 비활성")

func test_enemy_actions_shoot_only() -> void:
	var a := PartyActionMenu.enemy_actions(false, false, true)
	assert_false(_by_id(a, "move")["enabled"], "인접 못 감 → [이동] 비활성")
	assert_false(_by_id(a, "attack")["enabled"], "근접 불가 → [공격] 비활성")
	assert_true(_by_id(a, "shoot")["enabled"], "사거리 내 → [사격] 활성")

func test_enemy_actions_has_three_buttons() -> void:
	var a := PartyActionMenu.enemy_actions(true, true, true)
	assert_eq(a.size(), 3, "이동·공격·사격 3버튼")
