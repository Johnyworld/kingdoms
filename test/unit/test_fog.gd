extends GutTest
## 전장의 안개 상태 규칙 테스트: 현재 시야는 매번 교체, 탐험 기록은 누적.
## _draw/_process(뷰포트 의존)는 건드리지 않도록 씬 트리에 넣지 않고 검증한다.

var fog: Node2D

func before_each() -> void:
	fog = load("res://scenes/game/fog.gd").new()
	# 트리에 추가하지 않는다 → _process(뷰포트 의존) 미실행. update_visible은 순수 상태 변경.

func after_each() -> void:
	fog.free()

func _cells(list: Array) -> Dictionary:
	var d := {}
	for c in list:
		d[c] = true
	return d

func test_visible_records_current_cells() -> void:
	fog.update_visible(_cells([Vector2i(1, 1), Vector2i(2, 2)]))
	assert_true(fog._visible.has(Vector2i(1, 1)), "현재 시야에 포함")
	assert_true(fog._visible.has(Vector2i(2, 2)), "현재 시야에 포함")

func test_visible_is_replaced_each_update() -> void:
	fog.update_visible(_cells([Vector2i(1, 1)]))
	fog.update_visible(_cells([Vector2i(2, 2)]))
	assert_false(fog._visible.has(Vector2i(1, 1)), "이전 시야 셀은 현재 시야에서 빠진다")
	assert_true(fog._visible.has(Vector2i(2, 2)), "새 시야 셀만 남는다")

func test_explored_accumulates() -> void:
	fog.update_visible(_cells([Vector2i(1, 1)]))
	fog.update_visible(_cells([Vector2i(2, 2)]))
	assert_true(fog._explored.has(Vector2i(1, 1)), "탐험 기록은 유지된다")
	assert_true(fog._explored.has(Vector2i(2, 2)), "새 셀도 탐험 기록에 추가")

func test_explored_never_shrinks() -> void:
	fog.update_visible(_cells([Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)]))
	var before: int = fog._explored.size()
	fog.update_visible(_cells([]))  # 시야가 완전히 사라져도
	assert_eq(fog._explored.size(), before, "탐험 기록은 줄어들지 않는다")
