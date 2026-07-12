extends GutTest
## 공성(Siege) 순수 로직 — 사다리 상수 · 밀기 성공 판정. → docs/spec/features/wall.md

var siege = load("res://scenes/siege/siege.gd")

func test_ladder_constants() -> void:
	assert_eq(siege.LADDER_TURNS, 3, "설치 후 준비까지 3턴")
	assert_eq(siege.LADDER_PUSH_CHANCE, 0.15, "밀기 파괴 확률 0.15")
	assert_eq(siege.HOOKED_PUSH_REDUCTION, 0.05, "고리 사다리 밀기 감소분 0.05")

func test_push_succeeds_below_threshold() -> void:
	assert_true(siege.push_succeeds(0.10), "0.10 < 0.15 → 파괴 성공")

func test_push_fails_at_or_above_threshold() -> void:
	assert_false(siege.push_succeeds(0.20), "0.20 ≥ 0.15 → 실패")
	assert_false(siege.push_succeeds(0.15), "경계값 0.15는 미만만 성공이라 실패")

func test_push_markup_reduces_chance() -> void:
	# 고리 사다리 훅: markup 0.05 → 임계 0.10. roll 0.12는 0.10 이상이라 실패.
	assert_false(siege.push_succeeds(0.12, 0.05), "markup 0.05 → 임계 0.10, 0.12 실패")
	assert_true(siege.push_succeeds(0.08, 0.05), "markup 0.05 → 임계 0.10, 0.08 성공")
