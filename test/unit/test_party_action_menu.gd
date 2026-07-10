extends GutTest
## 부대 행동 메뉴 버튼 구성(PartyActionMenu) — 노드 비의존 순수 로직.
## party_actions(can_shoot_any): 중앙 메뉴 [사격][휴식][경계].
## enemy_actions(can_melee, can_shoot): 적 팝업 [공격][사격].

func _by_id(list: Array, id: String) -> Dictionary:
	for a in list:
		if a["id"] == id:
			return a
	return {}

func _ids(list: Array) -> Array:
	var out: Array = []
	for a in list:
		out.append(a["id"])
	return out

# --- 중앙 메뉴 (party_actions) ---

func test_party_actions_before_move() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(false, true)), ["shoot", "rest", "alert"], "이동 전 사격·휴식·경계")

func test_party_actions_after_move() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(true, true)), ["shoot", "wait"], "이동 후 사격·대기(휴식·경계 없음)")

func test_party_actions_shoot_enabled_by_target() -> void:
	assert_true(_by_id(PartyActionMenu.party_actions(false, true), "shoot")["enabled"], "사격 대상 있으면 활성")
	assert_false(_by_id(PartyActionMenu.party_actions(false, false), "shoot")["enabled"], "없으면 비활성")

func test_party_actions_rest_alert_wait_enabled() -> void:
	assert_true(_by_id(PartyActionMenu.party_actions(false, false), "rest")["enabled"], "휴식 활성")
	assert_true(_by_id(PartyActionMenu.party_actions(false, false), "alert")["enabled"], "경계 활성")
	assert_true(_by_id(PartyActionMenu.party_actions(true, false), "wait")["enabled"], "대기 활성")

# --- 적 팝업 (enemy_actions) ---

func test_enemy_actions_buttons() -> void:
	assert_eq(_ids(PartyActionMenu.enemy_actions(true, true)), ["attack", "shoot"], "공격·사격(이동 없음)")

func test_enemy_actions_melee_only() -> void:
	var a := PartyActionMenu.enemy_actions(true, false)
	assert_true(_by_id(a, "attack")["enabled"], "근접 가능 → 공격 활성")
	assert_false(_by_id(a, "shoot")["enabled"], "사거리 밖 → 사격 비활성")

func test_enemy_actions_shoot_only() -> void:
	var a := PartyActionMenu.enemy_actions(false, true)
	assert_false(_by_id(a, "attack")["enabled"], "근접 불가 → 공격 비활성")
	assert_true(_by_id(a, "shoot")["enabled"], "사거리 내 → 사격 활성")
