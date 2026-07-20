extends GutTest
## 약탈 패널(LootMenu) 테스트 — 내 인벤토리 장비 묶음 표시 로직 + Modal 개폐(closed 시그널).
## 선택 배선(가져오기 → loot_items)은 game.gd 실행 확인 몫이라, 여기선 순수 로직 위주로 검증한다.

func _menu() -> Object:
	var m: Object = load("res://scenes/loot/loot_menu.gd").new()
	add_child_autofree(m)   # _ready에서 UI 트리 구성
	return m

func _party(pname := "") -> Object:
	var p: Object = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.party_name = pname
	return p

func test_open_uses_modal_and_close_emits_closed() -> void:
	var m := _menu()
	watch_signals(m)
	m.open(_party(), _party("적 부대 A"), ["sword"])
	assert_true(m._modal.is_open(), "open → 공용 Modal 열림(ModalStack 등록)")
	assert_eq(m._modal.title, "약탈 — 적 부대 A", "Modal 제목 = 약탈 — 패자 부대명")
	m._close()
	assert_false(m._modal.is_open(), "close → Modal 닫힘")
	assert_signal_emitted(m, "closed", "닫히면 closed 방출(game.gd await 재개)")

func test_take_all_moves_loot_and_auto_closes() -> void:
	var m := _menu()
	var winner := _party()
	watch_signals(m)
	m.open(winner, _party("적"), ["sword", "bow"])
	m._on_take_all()
	assert_eq(winner.loot_items, ["sword", "bow"], "모두 가져오기 → 승자 loot_items로 전량 이동")
	assert_false(m._modal.is_open(), "노획 대상이 비면 자동 닫힘")
	assert_signal_emitted(m, "closed", "자동 닫힘도 closed 방출")

func test_grouped_lines_counts_by_name() -> void:
	var m := _menu()
	# 같은 id는 개수로 묶고, 첫 등장 순서를 유지한다.
	assert_eq(m._grouped_lines(["sword", "sword", "bow"]), ["검 ×2", "단궁 ×1"], "이름별 묶음·순서 유지")

func test_grouped_lines_empty() -> void:
	var m := _menu()
	assert_eq(m._grouped_lines([]), [], "빈 목록은 빈 배열")
