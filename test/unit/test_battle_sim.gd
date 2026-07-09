extends GutTest
## 헤드리스 전투 결산(BattleSim) 테스트 — 순수 함수. NPC끼리 전투를 화면 없이 결산.
## 확률은 극단 능력치로 강제한다: 회피 200↑ → 항상 빗나감 / 회피 음수 → 항상 명중.

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
	# 양측 모두 회피 200(항상 빗나감) → 상한 라운드까지 아무도 안 죽는다.
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

func test_deterministic_same_seed() -> void:
	var a := [_human(60, 20), _human(55, 25)]
	var b := [_human(58, 22), _human(52, 28)]
	var r1 := BattleSim.resolve_battle(a, b, _rng(7))
	var r2 := BattleSim.resolve_battle(a, b, _rng(7))
	assert_eq(r1["a"].size(), r2["a"].size(), "같은 시드 → 같은 A 생존 수")
	assert_eq(r1["b"].size(), r2["b"].size(), "같은 시드 → 같은 B 생존 수")
