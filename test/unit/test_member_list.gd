extends GutTest
## 구성원 리스트 위젯(MemberList) — Human 배열을 정렬·스크롤·키보드 이동되는 표(Tree 기반)로 그린다.
## 게임/세력을 모르고 Human만 안다. 정렬은 직접 구현, 스크롤·키보드 이동은 Tree 기본 동작.

var ml   # MemberList (extends Tree)

func before_each() -> void:
	ml = load("res://scenes/members/member_list.gd").new()
	add_child_autofree(ml)

func _human(p_name: String, stats := {}) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new(p_name)
	for k in stats:
		h.set(k, stats[k])
	return h

func _row_count() -> int:
	var root = ml.get_root()
	return 0 if root == null else root.get_child_count()

func test_lists_all_members() -> void:
	ml.set_members([_human("갑"), _human("을"), _human("병")])
	assert_eq(_row_count(), 3, "표 행 수 = 멤버 수")

func test_empty_members() -> void:
	ml.set_members([])
	assert_eq(_row_count(), 0, "빈 배열이면 행 없음")

func test_sorted_members_numeric_ascending() -> void:
	var a := _human("a", {"strength": 5})
	var b := _human("b", {"strength": 1})
	var c := _human("c", {"strength": 9})
	ml.set_members([a, b, c])
	var out: Array = ml.sorted_members("strength", true)
	assert_eq(out, [b, a, c], "힘 오름차순")

func test_sorted_members_numeric_descending() -> void:
	var a := _human("a", {"strength": 5})
	var b := _human("b", {"strength": 1})
	var c := _human("c", {"strength": 9})
	ml.set_members([a, b, c])
	var out: Array = ml.sorted_members("strength", false)
	assert_eq(out, [c, a, b], "힘 내림차순")

func test_sorted_members_does_not_mutate_input() -> void:
	var a := _human("a", {"strength": 5})
	var b := _human("b", {"strength": 1})
	var members := [a, b]
	ml.set_members(members)
	ml.sorted_members("strength", true)
	assert_eq(members, [a, b], "원본 배열 불변")

func test_sorted_members_by_name() -> void:
	var a := _human("다")
	var b := _human("가")
	var c := _human("나")
	ml.set_members([a, b, c])
	var out: Array = ml.sorted_members("human_name", true)
	assert_eq(out, [b, c, a], "이름 사전순")

func test_sorted_members_is_stable() -> void:
	# 스탯 동률이면 입력 순서를 유지(안정 정렬).
	var a := _human("a", {"charm": 7})
	var b := _human("b", {"charm": 7})
	var c := _human("c", {"charm": 7})
	ml.set_members([a, b, c])
	var out: Array = ml.sorted_members("charm", true)
	assert_eq(out, [a, b, c], "동률은 입력 순서 유지")

func test_sort_by_toggles_direction() -> void:
	var a := _human("a", {"charm": 5})
	var b := _human("b", {"charm": 1})
	ml.set_members([a, b])
	ml.sort_by("charm")
	assert_true(ml._sort_asc, "첫 클릭은 오름차순")
	ml.sort_by("charm")
	assert_false(ml._sort_asc, "같은 키 재클릭은 내림차순 토글")

func test_sort_by_new_key_starts_ascending() -> void:
	ml.set_members([_human("a", {"charm": 5, "luck": 2})])
	ml.sort_by("charm")
	ml.sort_by("charm")   # 내림차순 상태
	ml.sort_by("luck")    # 다른 키
	assert_eq(ml._sort_key, "luck", "정렬 키 변경")
	assert_true(ml._sort_asc, "다른 키는 오름차순으로 시작")

func test_selection_emits_member_selected() -> void:
	var a := _human("갑")
	var b := _human("을")
	ml.set_members([a, b])
	watch_signals(ml)
	ml.move_selection(1)   # 두 번째 행 선택
	assert_signal_emitted_with_parameters(ml, "member_selected", [b], "선택 행을 실어 방출")
	assert_eq(ml.selected_member(), b, "선택된 Human 반환")

func test_move_selection_clamps() -> void:
	var a := _human("갑")
	var b := _human("을")
	ml.set_members([a, b])
	ml.move_selection(-5)
	assert_eq(ml.selected_member(), a, "위로 넘치면 첫 행")
	ml.move_selection(99)
	assert_eq(ml.selected_member(), b, "아래로 넘치면 마지막 행")
