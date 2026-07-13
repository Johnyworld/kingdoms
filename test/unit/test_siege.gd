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

# --- 성벽 내구도 · 투석 데미지 → docs/spec/features/wall.md ---

func test_wall_durability_constants() -> void:
	assert_eq(siege.WALL_MAX_HP, 180, "성벽 만피 180")
	assert_eq(siege.DAMAGE_VARIANCE, 0.2, "데미지 랜덤 ±20%")

func test_rolled_damage_bounds() -> void:
	assert_eq(siege.rolled_damage(50, 0.0), 40, "roll 0 → 하한 40")
	assert_eq(siege.rolled_damage(50, 1.0), 60, "roll 1 → 상한 60")
	assert_eq(siege.rolled_damage(50, 0.5), 50, "roll 0.5 → 중앙 50")

func test_wall_after_hit() -> void:
	assert_eq(siege.wall_after_hit(180, 50), 130, "180 − 50 = 130")
	assert_eq(siege.wall_after_hit(30, 50), 0, "하한 0(음수 없음)")

func test_wall_broken() -> void:
	assert_true(siege.wall_broken(0), "0이면 붕괴")
	assert_false(siege.wall_broken(1), "1이면 아직")
	assert_true(siege.wall_broken(-5), "음수도 붕괴")

func test_wall_breaks_in_three_to_five_shots() -> void:
	# 최대 데미지(60)면 3발, 최소(40)면 5발에 붕괴(평균 3~5발).
	var hp_max: int = siege.WALL_MAX_HP
	var shots_min := 0
	var hp: int = hp_max
	while hp > 0:
		hp = siege.wall_after_hit(hp, siege.rolled_damage(50, 1.0))   # 최대 데미지 60
		shots_min += 1
	assert_eq(shots_min, 3, "최대 데미지면 3발")
	var shots_max := 0
	hp = hp_max
	while hp > 0:
		hp = siege.wall_after_hit(hp, siege.rolled_damage(50, 0.0))   # 최소 데미지 40
		shots_max += 1
	assert_eq(shots_max, 5, "최소 데미지면 5발")
