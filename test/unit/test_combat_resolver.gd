extends GutTest
## 전투 판정 로직(CombatResolver) 테스트 — 순수 함수. 능력치를 직접 설정한 Human으로 검증.
## 확률은 극단 능력치로 강제한다: 회피 100↑ → 항상 빗나감 / 회피 음수 → 항상 명중 / 행운 큼 → 항상 치명.

func _human(strength := 0, agility := 0, luck := 0, hp := 40) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new()
	h.strength = strength
	h.agility = agility
	h.luck = luck
	h.hit_points = hp
	return h

func _rng(seed_val := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

# --- 계산 스탯 (결정적) ---

func test_attack_power_floor_of_strength_over_five() -> void:
	assert_eq(CombatResolver.attack_power(_human(78)), 15, "힘 78 → floor(78/5)=15")
	assert_eq(CombatResolver.attack_power(_human(4)), 0, "힘 4 → floor(4/5)=0")

func test_evasion_half_agility() -> void:
	assert_eq(CombatResolver.evasion(_human(0, 40)), 20.0, "민첩 40 → 회피 20")

func test_hit_chance_ninety_minus_evasion() -> void:
	var attacker := _human()
	var defender := _human(0, 40)   # 회피 20
	assert_eq(CombatResolver.hit_chance(attacker, defender), 70.0, "명중 = 90 − 20 = 70")

func test_crit_chance_half_luck() -> void:
	assert_eq(CombatResolver.crit_chance(_human(0, 0, 60)), 30.0, "행운 60 → 치명 30")

func test_hit_damage_min_one_and_crit_multiplier() -> void:
	assert_eq(CombatResolver.hit_damage(_human(78), false), 15, "AT 15 평타 → 15")
	assert_eq(CombatResolver.hit_damage(_human(78), true), 22, "AT 15 치명 → floor(15×1.5)=22")
	assert_eq(CombatResolver.hit_damage(_human(4), false), 1, "AT 0이어도 최소 1")

# --- 1회 공방 (resolve_hit) ---

func test_hit_always_misses_when_evasion_maxed() -> void:
	var attacker := _human(78)
	var defender := _human(0, 200)   # 회피 100 → 명중 −10 → 항상 빗나감
	var r := CombatResolver.resolve_hit(attacker, defender, 40, _rng())
	assert_false(r["hit"], "회피 100이면 빗나감")
	assert_eq(r["damage"], 0, "빗나가면 피해 0")
	assert_eq(r["hp"], 40, "빗나가면 hp 불변")

func test_hit_applies_damage_and_updates_hp() -> void:
	var attacker := _human(78)          # AT 15
	var defender := _human(0, -100)     # 회피 −50 → 명중 140 → 항상 명중, 행운 0 → 치명 없음
	var r := CombatResolver.resolve_hit(attacker, defender, 40, _rng())
	assert_true(r["hit"], "회피 음수면 항상 명중")
	assert_eq(r["damage"], 15, "AT 15 평타 피해 15")
	assert_eq(r["hp"], 25, "hp 40 − 15 = 25")
	assert_false(r["dead"], "25 > 0 이므로 생존")

func test_hit_deterministic_same_seed() -> void:
	var a := _human(50, 30, 40)
	var b := _human(50, 30, 40)
	var r1 := CombatResolver.resolve_hit(a, b, 40, _rng(7))
	var r2 := CombatResolver.resolve_hit(a, b, 40, _rng(7))
	assert_eq(r1, r2, "같은 시드 → 같은 결과")

# --- 교전 (resolve_engagement) ---

func test_engagement_all_miss_no_deaths() -> void:
	var a := _human(78, 200)   # 둘 다 회피 100 → 항상 빗나감
	var b := _human(78, 200)
	var r := CombatResolver.resolve_engagement(a, b, 40, 40, _rng())
	assert_eq(r["a_hp"], 40, "빗나가기만 하면 a hp 불변")
	assert_eq(r["b_hp"], 40, "빗나가기만 하면 b hp 불변")
	assert_false(r["a_dead"], "생존")
	assert_false(r["b_dead"], "생존")

func test_engagement_initiator_one_shots_and_takes_no_hit() -> void:
	var a := _human(1000, 0, 0)     # AT 200 → 한 방에 즉사시킴
	var b := _human(0, -100, 0)     # 회피 음수 → a의 공격 항상 명중
	var r := CombatResolver.resolve_engagement(a, b, 40, 40, _rng())
	assert_true(r["b_dead"], "개시자 선공에 대상 전투불능")
	assert_false(r["a_dead"], "선공 이점 — 대상이 먼저 죽어 반격 없음")
	assert_eq(r["a_hp"], 40, "개시자 hp 불변")

func test_engagement_hp_never_increases() -> void:
	var a := _human(50, 20, 40)
	var b := _human(50, 20, 40)
	var r := CombatResolver.resolve_engagement(a, b, 40, 40, _rng(3))
	assert_true(r["a_hp"] <= 40, "a hp는 초기값을 넘지 않음")
	assert_true(r["b_hp"] <= 40, "b hp는 초기값을 넘지 않음")

func test_engagement_deterministic_same_seed() -> void:
	var a := _human(50, 20, 40)
	var b := _human(50, 20, 40)
	var r1 := CombatResolver.resolve_engagement(a, b, 40, 40, _rng(5))
	var r2 := CombatResolver.resolve_engagement(a, b, 40, 40, _rng(5))
	assert_eq(r1, r2, "같은 시드 → 같은 결과")
