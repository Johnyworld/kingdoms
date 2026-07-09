extends GutTest
## 헤드리스 전투 결산(BattleSim) 테스트 — 순수 함수. NPC끼리 전투를 화면 없이 결산.
## 확률은 극단 능력치로 강제한다: 회피 200↑ → 항상 빗나감 / 회피 음수 → 항상 명중.

func _human(strength := 0, agility := 0, luck := 0, hp := 40, weapon := "") -> Object:
	return _human_weapons(strength, agility, luck, hp, ([] if weapon == "" else [weapon]))

func _human_weapons(strength := 0, agility := 0, luck := 0, hp := 40, weapons := []) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new()
	h.strength = strength
	h.agility = agility
	h.luck = luck
	h.hit_points = hp
	h.weapons = weapons
	return h

func _rng(seed_val := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

func test_dominant_side_wipes_other() -> void:
	# A는 일격 필살(힘 1000 → AT 200). B는 회피 음수(-50) → A가 항상 명중해 즉사시킨다.
	# 개시자 선공이라 B는 반격 전에 죽어 A는 무사하다.
	var a := [_human(1000, 0), _human(1000, 0)]
	var b := [_human(1, -100), _human(1, -100)]
	var r := BattleSim.resolve_battle(a, b, _rng())
	assert_eq(r["b"].size(), 0, "압도적인 A에게 B 전멸")
	assert_eq(r["a"].size(), 2, "A는 전원 생존(선공으로 반격 전에 처치)")

func test_survivors_subset_of_members() -> void:
	var a := [_human(60, 20), _human(60, 20)]
	var b := [_human(60, 20)]
	var r := BattleSim.resolve_battle(a, b, _rng(3))
	for h in r["a"]:
		assert_true(h in a, "A 생존자는 원래 A 멤버")
	for h in r["b"]:
		assert_true(h in b, "B 생존자는 원래 B 멤버")

func test_all_miss_no_deaths() -> void:
	# 양측 모두 회피 200(항상 빗나감) → 10초간 계속 공격해도 아무도 안 죽는다.
	var a := [_human(60, 200), _human(60, 200)]
	var b := [_human(60, 200)]
	var r := BattleSim.resolve_battle(a, b, _rng())
	assert_eq(r["a"].size(), 2, "A 전원 생존")
	assert_eq(r["b"].size(), 1, "B 전원 생존")

func test_empty_side_leaves_other_intact() -> void:
	var a := [_human(60, 20), _human(60, 20)]
	var r := BattleSim.resolve_battle(a, [], _rng())
	assert_eq(r["a"].size(), 2, "상대가 없으면 A 전원 생존")
	assert_eq(r["b"].size(), 0, "빈 팀은 생존자 0")

func test_ranged_mode_only_ranged_attacks() -> void:
	# 원거리 모드: A는 활(원거리, 강함), B는 검(근접) → A만 공격 → B 전멸, A 무사.
	var a := [_human(1000, 0, 0, 40, "bow")]      # 강함(일격)
	var b := [_human(1000, -100, 0, 40, "sword")] # 회피 음수 → A가 항상 명중, 근접이라 반격 불가
	var r := BattleSim.resolve_battle(a, b, _rng(), true)
	assert_eq(r["b"].size(), 0, "근접만 든 B는 반격 못 하고 전멸")
	assert_eq(r["a"].size(), 1, "원거리 A는 무사")

func test_ranged_mode_secondary_bow_can_retaliate() -> void:
	# 원거리 모드: A는 활만, B는 검+활(보조). B는 활로 반격 가능 → 양측 사격.
	# A가 항상 명중·즉사시키지만, B도 활을 들어 '행동 가능'하다(공격 못 하는 검전용과 대비).
	var a := [_human(1000, -100, 0, 40, "bow")]
	var b := [_human_weapons(1000, -100, 0, 40, ["sword", "bow"])]
	var r := BattleSim.resolve_battle(a, b, _rng(), true)
	# 둘 다 활을 들어 서로 사격 — 선(先)순회한 A가 먼저 B를 처치(항상 명중·즉사).
	assert_eq(r["b"].size(), 0, "검+활 B도 사격 대상이 되고, 먼저 맞아 전멸")
	assert_eq(r["a"].size(), 1, "A 생존")

func test_ranged_mode_melee_only_cannot_retaliate() -> void:
	# 대조군: B가 검만 들면 원거리 모드에서 공격(반격) 자체를 못 한다(활 없음).
	var a := [_human(1, 200, 0, 40, "bow")]        # 회피 높은 상대라 A는 못 맞힘(무피해)
	var b := [_human(1, 200, 0, 40, "sword")]      # 검만 → 원거리 모드 공격 불가
	var r := BattleSim.resolve_battle(a, b, _rng(), true)
	assert_eq(r["a"].size(), 1, "A 생존")
	assert_eq(r["b"].size(), 1, "B 생존 — 검만이라 애초에 공격 못 함")

func test_ranged_mode_both_melee_no_damage() -> void:
	# 원거리 모드 + 양팀 근접만 → 아무도 공격 못 해 전원 생존.
	var a := [_human(1000, -100, 0, 40, "sword")]
	var b := [_human(1000, -100, 0, 40, "sword")]
	var r := BattleSim.resolve_battle(a, b, _rng(), true)
	assert_eq(r["a"].size(), 1, "근접만이라 A 공격 못 함 → 생존")
	assert_eq(r["b"].size(), 1, "근접만이라 B 공격 못 함 → 생존")

func test_deterministic_same_seed() -> void:
	var a := [_human(60, 20), _human(55, 25)]
	var b := [_human(58, 22), _human(52, 28)]
	var r1 := BattleSim.resolve_battle(a, b, _rng(7))
	var r2 := BattleSim.resolve_battle(a, b, _rng(7))
	assert_eq(r1["a"].size(), r2["a"].size(), "같은 시드 → 같은 A 생존 수")
	assert_eq(r1["b"].size(), r2["b"].size(), "같은 시드 → 같은 B 생존 수")
