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
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, false)), ["shoot", "rest", "alert"], "이동 전 사격·휴식·경계")

func test_party_actions_after_move() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(true, true, false)), ["shoot", "wait"], "이동 후 사격·대기(휴식·경계 없음)")

func test_party_actions_after_move_with_undo() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(true, false, true)), ["shoot", "wait", "undo"], "되돌리기 가능하면 취소 추가")

func test_party_actions_no_undo_before_move() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, true)), ["shoot", "rest", "alert"], "이동 전이면 can_undo여도 취소 없음")

func test_party_actions_shoot_enabled_by_target() -> void:
	assert_true(_by_id(PartyActionMenu.party_actions(false, true, false), "shoot")["enabled"], "사격 대상 있으면 활성")
	assert_false(_by_id(PartyActionMenu.party_actions(false, false, false), "shoot")["enabled"], "없으면 비활성")

func test_party_actions_rest_alert_wait_enabled() -> void:
	assert_true(_by_id(PartyActionMenu.party_actions(false, false, false), "rest")["enabled"], "휴식 활성")
	assert_true(_by_id(PartyActionMenu.party_actions(false, false, false), "alert")["enabled"], "경계 활성")
	assert_true(_by_id(PartyActionMenu.party_actions(true, false, false), "wait")["enabled"], "대기 활성")

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

# --- 거점 점령 팝업 (capture_actions) ---

func test_capture_actions_buttons() -> void:
	assert_eq(_ids(PartyActionMenu.capture_actions()), ["absorb", "destroy"], "점령 팝업 [흡수][파괴]")

func test_capture_actions_both_enabled() -> void:
	var a := PartyActionMenu.capture_actions()
	assert_true(_by_id(a, "absorb")["enabled"], "흡수 활성")
	assert_true(_by_id(a, "destroy")["enabled"], "파괴 활성")

# --- 방어된 캠프 공격 팝업 (camp_attack_actions) ---

func test_camp_attack_actions_buttons() -> void:
	assert_eq(_ids(PartyActionMenu.camp_attack_actions()), ["attack"], "방어 캠프 팝업 [공격]")

func test_camp_attack_actions_enabled() -> void:
	assert_true(_by_id(PartyActionMenu.camp_attack_actions(), "attack")["enabled"], "공격 활성")

# --- 병합 팝업 (merge_actions) ---

func test_merge_actions_button() -> void:
	assert_eq(_ids(PartyActionMenu.merge_actions()), ["merge"], "인접 아군 팝업 [병합]")

# --- 분할 버튼 (party_actions can_split) ---

func test_party_actions_split_when_can() -> void:
	# 이동 전 + 분할 가능 → [사격][휴식][경계][분할].
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, false, true)), ["shoot", "rest", "alert", "split"], "분할 가능 시 분할 버튼 추가")

func test_party_actions_no_split_when_cannot() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, false, false)), ["shoot", "rest", "alert"], "분할 불가 시 분할 없음")

func test_party_actions_no_split_after_move() -> void:
	# 이동 후에는 분할 없음(휴식·경계와 동일).
	assert_eq(_ids(PartyActionMenu.party_actions(true, true, false, true)), ["shoot", "wait"], "이동 후엔 분할 없음")
