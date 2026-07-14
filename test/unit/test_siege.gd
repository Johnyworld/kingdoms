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

# --- 사다리 공성 유지 카운트(부대가 자리 지킬 때만 진행) → docs/spec/features/wall.md ---

func test_advance_ladder_countdown_manned() -> void:
	assert_eq(siege.advance_ladder_countdown(3, true), 2, "유지 중 −1")
	assert_eq(siege.advance_ladder_countdown(1, true), 0, "1 → 0(준비 완료)")

func test_advance_ladder_countdown_unmanned_pauses() -> void:
	assert_eq(siege.advance_ladder_countdown(3, false), 3, "유지 끊기면 정지(리셋 아님)")

func test_advance_ladder_countdown_floor() -> void:
	assert_eq(siege.advance_ladder_countdown(0, true), 0, "하한 0(유지 중)")
	assert_eq(siege.advance_ladder_countdown(0, false), 0, "준비 완료는 유지 무관 0")

# --- 성벽 내구도 · 투석 데미지 → docs/spec/features/wall.md ---

func test_wall_durability_constants() -> void:
	assert_eq(siege.WALL_MAX_HP, 180, "성벽 만피 180")
	assert_eq(siege.DAMAGE_VARIANCE, 0.4, "데미지 랜덤 ±40%")

func test_rolled_damage_bounds() -> void:
	assert_eq(siege.rolled_damage(50, 0.0), 30, "roll 0 → 하한 30")
	assert_eq(siege.rolled_damage(50, 1.0), 70, "roll 1 → 상한 70")
	assert_eq(siege.rolled_damage(50, 0.5), 50, "roll 0.5 → 중앙 50")

func test_wall_after_hit() -> void:
	assert_eq(siege.wall_after_hit(180, 50), 130, "180 − 50 = 130")
	assert_eq(siege.wall_after_hit(30, 50), 0, "하한 0(음수 없음)")

func test_wall_broken() -> void:
	assert_true(siege.wall_broken(0), "0이면 붕괴")
	assert_false(siege.wall_broken(1), "1이면 아직")
	assert_true(siege.wall_broken(-5), "음수도 붕괴")

func test_wall_breaks_in_three_to_six_shots() -> void:
	# 최대 데미지(70)면 3발, 최소(30)면 6발에 붕괴(평균 3~6발).
	var hp_max: int = siege.WALL_MAX_HP
	var shots_min := 0
	var hp: int = hp_max
	while hp > 0:
		hp = siege.wall_after_hit(hp, siege.rolled_damage(50, 1.0))   # 최대 데미지 70
		shots_min += 1
	assert_eq(shots_min, 3, "최대 데미지면 3발")
	var shots_max := 0
	hp = hp_max
	while hp > 0:
		hp = siege.wall_after_hit(hp, siege.rolled_damage(50, 0.0))   # 최소 데미지 30
		shots_max += 1
	assert_eq(shots_max, 6, "최소 데미지면 6발")

# --- 유닛 투석 판정 → docs/spec/features/siege-engines.md ---

func test_bombard_constants() -> void:
	assert_eq(siege.MAX_BOMBARD_TARGETS, 5, "최대 표적 5명")
	assert_eq(siege.CATAPULT_HIT_CHANCE, 0.1, "명중률 0.1(낮음)")

func test_hit_succeeds() -> void:
	assert_true(siege.hit_succeeds(0.05, 0.1), "0.05 < 0.1 → 명중")
	assert_false(siege.hit_succeeds(0.2, 0.1), "0.2 ≥ 0.1 → 빗나감")
	assert_false(siege.hit_succeeds(0.1, 0.1), "경계 0.1은 미만만 명중이라 빗나감")

# --- 사거리 밴드 판정(5f, 로빙 positioning 공성) → docs/spec/features/siege-engines.md ---

func test_in_fire_band_inside() -> void:
	assert_true(siege.in_fire_band(4, 4, 5), "거리 4는 밴드 4~5 안")
	assert_true(siege.in_fire_band(5, 4, 5), "거리 5는 밴드 4~5 안")

func test_in_fire_band_outside() -> void:
	assert_false(siege.in_fire_band(3, 4, 5), "거리 3은 밴드보다 가까움 — 근거리 투석 불가")
	assert_false(siege.in_fire_band(6, 4, 5), "거리 6은 밴드보다 멀음")
	assert_false(siege.in_fire_band(0, 4, 5), "거점 위(0)는 밴드 밖")

func test_in_fire_band_single_cell() -> void:
	assert_true(siege.in_fire_band(4, 4, 4), "min==fire 단일 셀 밴드는 그 거리만 참")

# --- 헤드리스 성벽 투석 피해 총량(5g, NPC↔NPC 성벽 공성) → docs/spec/features/siege-engines.md ---

func test_total_bombard_damage_sums_rolls() -> void:
	assert_eq(siege.total_bombard_damage([50, 50], [0.0, 1.0]), 100, "30 + 70 = 100 (유닛별 rolled_damage 합)")

func test_total_bombard_damage_single() -> void:
	assert_eq(siege.total_bombard_damage([50], [0.5]), 50, "1대 = rolled_damage 그대로")

func test_total_bombard_damage_edges() -> void:
	assert_eq(siege.total_bombard_damage([], []), 0, "공성 유닛 없음 → 0")
	assert_eq(siege.total_bombard_damage([50, 50], [1.0]), 70, "둘 중 짧은 길이(1발)만큼 — 70")

# --- 충차 반격 피해(5h, 근접 대성벽 공성) → docs/spec/features/siege-engines.md ---

func test_gate_max_hp() -> void:
	assert_eq(siege.GATE_MAX_HP, 120, "성문 내구도 120")

func test_ram_counter_base() -> void:
	assert_eq(siege.RAM_COUNTER_BASE, 15, "충차 반격 기준 피해 15")

func test_ram_counter_damage_bounds() -> void:
	assert_eq(siege.ram_counter_damage(0.0), 9, "15×0.6 하한")
	assert_eq(siege.ram_counter_damage(1.0), 21, "15×1.4 상한")
	assert_eq(siege.ram_counter_damage(0.5), 15, "기준값")
