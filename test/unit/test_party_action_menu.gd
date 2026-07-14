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
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, false)), ["shoot", "rest", "alert", "equip"], "이동 전 사격·휴식·경계·장비")

func test_party_actions_after_move() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(true, true, false)), ["shoot", "wait", "equip"], "이동 후 사격·대기·장비(휴식·경계 없음)")

func test_party_actions_after_move_with_undo() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(true, false, true)), ["shoot", "wait", "undo", "equip"], "되돌리기 가능하면 취소 추가(장비는 맨 뒤)")

func test_party_actions_no_undo_before_move() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, true)), ["shoot", "rest", "alert", "equip"], "이동 전이면 can_undo여도 취소 없음(장비는 맨 뒤)")

func test_party_actions_shoot_enabled_by_target() -> void:
	assert_true(_by_id(PartyActionMenu.party_actions(false, true, false), "shoot")["enabled"], "사격 대상 있으면 활성")
	assert_false(_by_id(PartyActionMenu.party_actions(false, false, false), "shoot")["enabled"], "없으면 비활성")

func test_party_actions_rest_alert_wait_enabled() -> void:
	assert_true(_by_id(PartyActionMenu.party_actions(false, false, false), "rest")["enabled"], "휴식 활성")
	assert_true(_by_id(PartyActionMenu.party_actions(false, false, false), "alert")["enabled"], "경계 활성")
	assert_true(_by_id(PartyActionMenu.party_actions(true, false, false), "wait")["enabled"], "대기 활성")

# --- 자동 추종 버튼 ([자동]) ---

func test_party_actions_auto_follow_off_label() -> void:
	var a := PartyActionMenu.party_actions(false, true, false, false, false, false, false, false, false, false, true, false)
	assert_true("auto" in _ids(a), "자동 토글 가능하면 [자동] 포함")
	assert_eq(_by_id(a, "auto")["label"], "추종 켜기", "꺼짐이면 '추종 켜기'")

func test_party_actions_auto_follow_on_label() -> void:
	var a := PartyActionMenu.party_actions(false, true, false, false, false, false, false, false, false, false, true, true)
	assert_eq(_by_id(a, "auto")["label"], "추종 끄기", "켜짐이면 '추종 끄기'")

func test_party_actions_auto_before_equip() -> void:
	var ids := _ids(PartyActionMenu.party_actions(false, true, false, false, false, false, false, false, false, false, true, false))
	assert_eq(ids[ids.size() - 2], "auto", "[자동]은 [장비] 바로 앞")
	assert_eq(ids[ids.size() - 1], "equip", "[장비]는 맨 뒤")

func test_party_actions_no_auto_when_disabled() -> void:
	assert_false("auto" in _ids(PartyActionMenu.party_actions(false, true, false)), "can_auto_follow 없으면 [자동] 없음")

func test_party_actions_no_auto_when_stationed() -> void:
	# 주둔 중이면 can_auto_follow와 무관하게 [자동] 없음(주둔 목록만).
	var a := PartyActionMenu.party_actions(false, false, false, false, false, true, false, false, false, false, true, false)
	assert_false("auto" in _ids(a), "주둔 중이면 [자동] 없음")

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

# --- 주둔 / 주둔 종료 (party_actions on_center·stationed) ---

func test_party_actions_station_on_center() -> void:
	# 거점 위·미행동·주둔 아님 → [주둔]이 [장비] 앞에 추가.
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, false, false, true)), ["shoot", "rest", "alert", "station", "equip"], "거점 위면 주둔 버튼 추가")

func test_party_actions_no_station_off_center() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, false, false, false)), ["shoot", "rest", "alert", "equip"], "거점 밖이면 주둔 없음")

func test_party_actions_unstation_when_stationed() -> void:
	# 주둔 중 + 사격 대상 없음 → [주둔 종료][장비]만(다른 행동 없음).
	assert_eq(_ids(PartyActionMenu.party_actions(false, false, false, false, true, true)), ["unstation", "equip"], "주둔 중·사격 대상 없으면 주둔 종료·장비만")

func test_party_actions_stationed_shoot_when_target() -> void:
	# 주둔 중 + 사격 가능 적 있음(can_shoot_any) → [사격]이 맨 앞(주둔 유지한 채 제자리 사격).
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, false, false, true, true)), ["shoot", "unstation", "equip"], "주둔 중·사격 대상 있으면 사격이 맨 앞")

# --- 사다리 (party_actions can_place_ladder / can_push_ladder) ---

func test_party_actions_place_ladder() -> void:
	# 비주둔·성벽 적 거점 인접(can_place_ladder) → [사다리 설치]가 [장비] 앞.
	assert_eq(_ids(PartyActionMenu.party_actions(false, false, false, false, false, false, true)), ["shoot", "rest", "alert", "ladder", "equip"], "성벽 적 거점 인접이면 사다리 설치 추가")

func test_party_actions_no_ladder_when_cannot() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(false, false, false, false, false, false, false)), ["shoot", "rest", "alert", "equip"], "인접 아니면 사다리 설치 없음")

func test_party_actions_push_ladder_when_stationed() -> void:
	# 주둔 중 + 자기 거점 겨눈 사다리 있음(can_push_ladder) → [사다리 밀기] 포함.
	var ids := _ids(PartyActionMenu.party_actions(false, false, false, false, true, true, false, true))
	assert_has(ids, "push_ladder", "주둔 방어 부대는 사다리 있으면 사다리 밀기")
	assert_does_not_have(ids, "ladder", "설치는 주둔 중엔 없음")

func test_party_actions_no_push_ladder_when_none() -> void:
	assert_does_not_have(_ids(PartyActionMenu.party_actions(false, false, false, false, true, true, false, false)), "push_ladder", "겨눈 사다리 없으면 밀기 없음")

# --- 투석 (party_actions can_bombard) → docs/spec/features/siege-engines.md ---

func test_party_actions_bombard_when_can() -> void:
	# 비주둔 + 투석기 실음 + 사거리 안 성벽 적 거점(can_bombard) → [투석]이 [장비] 앞.
	var ids := _ids(PartyActionMenu.party_actions(false, false, false, false, false, false, false, false, true))
	assert_has(ids, "catapult", "투석 가능 시 [투석] 추가")
	assert_true(ids.find("catapult") < ids.find("equip"), "[투석]은 [장비] 앞")

func test_party_actions_no_bombard_when_cannot() -> void:
	assert_does_not_have(_ids(PartyActionMenu.party_actions(false, false, false, false, false, false, false, false, false)), "catapult", "투석 대상 없으면 [투석] 없음")

# --- 병합 팝업 (merge_actions) ---

func test_merge_actions_button() -> void:
	assert_eq(_ids(PartyActionMenu.merge_actions()), ["merge"], "인접 아군 팝업 [병합]")

# --- 분할 버튼 (party_actions can_split) ---

func test_party_actions_split_when_can() -> void:
	# 이동 전 + 분할 가능 → [사격][휴식][경계][분할].
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, false, true)), ["shoot", "rest", "alert", "split", "equip"], "분할 가능 시 분할 버튼 추가(장비는 맨 뒤)")

func test_party_actions_no_split_when_cannot() -> void:
	assert_eq(_ids(PartyActionMenu.party_actions(false, true, false, false)), ["shoot", "rest", "alert", "equip"], "분할 불가 시 분할 없음(장비는 맨 뒤)")

func test_party_actions_no_split_after_move() -> void:
	# 이동 후에는 분할 없음(휴식·경계와 동일).
	assert_eq(_ids(PartyActionMenu.party_actions(true, true, false, true)), ["shoot", "wait", "equip"], "이동 후엔 분할 없음(장비는 맨 뒤)")

func test_party_actions_equip_always_last() -> void:
	# [장비]는 이동 전/후 항상 맨 뒤에 온다(턴 소비 없음).
	var before := PartyActionMenu.party_actions(false, true, false)
	assert_eq(before[-1]["id"], "equip", "이동 전 마지막은 장비")
	assert_true(before[-1]["enabled"], "장비 항상 활성")
	var after := PartyActionMenu.party_actions(true, true, false)
	assert_eq(after[-1]["id"], "equip", "이동 후 마지막은 장비")

# --- 소속([소속]) — party-lord.md ---

func test_party_actions_lord_when_can_manage() -> void:
	# 일반부대 + 소속 관리 가능 → [소속]이 장비 바로 앞.
	var out := PartyActionMenu.party_actions(false, true, false, false, false, false, false, false, false, true)
	assert_eq(_ids(out), ["shoot", "rest", "alert", "lord", "equip"], "소속 버튼이 장비 앞에 추가")

func test_party_actions_no_lord_when_cannot() -> void:
	var out := PartyActionMenu.party_actions(false, true, false, false, false, false, false, false, false, false)
	assert_false("lord" in _ids(out), "소속 관리 불가 시 [소속] 없음")

func test_party_actions_no_lord_when_stationed() -> void:
	# 주둔 중이면 can_manage_lord와 무관하게 [소속] 없음(주둔 목록만).
	var out := PartyActionMenu.party_actions(false, false, false, false, false, true, false, false, false, true)
	assert_false("lord" in _ids(out), "주둔 중 [소속] 없음")
