extends GutTest
## 약탈 패널(LootMenu) 테스트 — 내 인벤토리 장비 묶음 표시 로직.
## 패널 개폐·선택 배선은 game.gd 실행 확인 몫이라, 여기선 순수 로직(_grouped_lines)만 검증한다.

func _menu() -> Object:
	var m: Object = load("res://scenes/loot/loot_menu.gd").new()
	add_child_autofree(m)   # _ready에서 UI 트리 구성
	return m

func test_grouped_lines_counts_by_name() -> void:
	var m := _menu()
	# 같은 id는 개수로 묶고, 첫 등장 순서를 유지한다.
	assert_eq(m._grouped_lines(["sword", "sword", "bow"]), ["검 ×2", "단궁 ×1"], "이름별 묶음·순서 유지")

func test_grouped_lines_empty() -> void:
	var m := _menu()
	assert_eq(m._grouped_lines([]), [], "빈 목록은 빈 배열")
