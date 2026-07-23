extends GutTest
## 부대 행동 팝업 버튼 구성(PartyActionMenu) — 노드 비의존 순수 로직.
## 중앙 메뉴(party_actions)·적 공격 팝업(enemy_actions)·작전 메뉴(stance_actions)는 공격 통합·[소속]/[지휘] 이전으로 삭제됨.
## 남은 팝업: capture_actions([흡수][파괴]), merge_actions([병합]).

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

# --- 거점 점령 팝업 (capture_actions) ---

func test_capture_actions_buttons() -> void:
	assert_eq(_ids(PartyActionMenu.capture_actions()), ["absorb", "destroy"], "점령 팝업 [흡수][파괴]")

func test_capture_actions_both_enabled() -> void:
	var a := PartyActionMenu.capture_actions()
	assert_true(_by_id(a, "absorb")["enabled"], "흡수 활성")
	assert_true(_by_id(a, "destroy")["enabled"], "파괴 활성")

# --- 병합 팝업 (merge_actions) ---

func test_merge_actions_button() -> void:
	assert_eq(_ids(PartyActionMenu.merge_actions()), ["merge"], "인접 아군 팝업 [병합]")
