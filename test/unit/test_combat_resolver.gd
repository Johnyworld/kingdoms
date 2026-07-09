extends GutTest
## 전투 판정 로직(CombatResolver) 테스트 — 순수 함수. 능력치를 직접 설정한 Human으로 검증.
## 확률은 극단 능력치로 강제한다: 회피 100↑ → 항상 빗나감 / 회피 음수 → 항상 명중 / 행운 큼 → 항상 치명.

func _human(strength := 0, agility := 0, luck := 0, hp := 40, weapon := "", armor := [], shield := "") -> Object:
	var h: Object = load("res://scenes/human/human.gd").new()
	h.strength = strength
	h.agility = agility
	h.luck = luck
	h.hit_points = hp
	h.weapons = ([] if weapon == "" else [weapon])
	h.armor = armor
	h.shield = shield
	return h

func _human_weapons(strength := 0, weapons := []) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new()
	h.strength = strength
	h.agility = 0   # 공격 간격 테스트가 민첩 0 기준이 되도록 명시
	h.weapons = weapons
	return h

func _rng(seed_val := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

# --- 계산 스탯 (결정적) ---

func test_attack_power_floor_of_strength_over_five() -> void:
	assert_eq(CombatResolver.attack_power(_human(78)), 15, "맨몸 힘 78 → floor(78/5)=15")
	assert_eq(CombatResolver.attack_power(_human(4)), 0, "맨몸 힘 4 → floor(4/5)=0")

func test_attack_power_includes_weapon() -> void:
	assert_eq(CombatResolver.attack_power(_human(78, 0, 0, 40, "sword")), 29, "검(14)+floor(78/5)=29")

func test_attack_power_uses_primary_by_default() -> void:
	# 검+활 소지 → 인자 생략 시 주무기(검, 14) 기준.
	var h := _human_weapons(78, ["sword", "bow"])
	assert_eq(CombatResolver.attack_power(h), 29, "생략 시 주무기 검(14)+15=29")

func test_attack_power_explicit_weapon() -> void:
	# 무기 id를 명시하면 그 무기로 계산 — 활(12)+15=27.
	var h := _human_weapons(78, ["sword", "bow"])
	assert_eq(CombatResolver.attack_power(h, "bow"), 27, "활(12)+floor(78/5)=27")

func test_defense_sums_armor() -> void:
	assert_eq(CombatResolver.defense(_human()), 0, "맨몸 방어력 0")
	var set := ["leather_helm", "leather_armor", "leather_gloves", "leather_greaves"]  # 17
	assert_eq(CombatResolver.defense(_human(0, 0, 0, 40, "", set)), 17, "가죽 세트 방어력 합 17")

func test_defense_includes_shield() -> void:
	# 가죽 세트(17) + 타워 실드(12) = 29.
	var set := ["leather_helm", "leather_armor", "leather_gloves", "leather_greaves"]
	assert_eq(CombatResolver.defense(_human(0, 0, 0, 40, "", set, "tower_shield")), 29, "방어구+방패 방어력 합")

func test_block_chance() -> void:
	assert_eq(CombatResolver.block_chance(_human()), 0, "방패 없으면 막기 0")
	assert_eq(CombatResolver.block_chance(_human(0, 0, 0, 40, "", [], "tower_shield")), 40, "타워 실드 막기 40")

func test_evasion_half_agility() -> void:
	assert_eq(CombatResolver.evasion(_human(0, 40)), 20.0, "맨몸 민첩 40 → 회피 20")

func test_equip_weight_sums() -> void:
	assert_eq(CombatResolver.equip_weight(_human()), 0, "맨몸 무게 0")
	# 검(3) + 사슬갑옷(8) + 타워실드(8) = 19.
	var h := _human(0, 0, 0, 40, "sword", ["chain_mail"], "tower_shield")
	assert_eq(CombatResolver.equip_weight(h), 19, "무기+방어구+방패 무게 합")

func test_equip_weight_sums_all_weapons() -> void:
	# 검(3) + 활(2) = 5 — 보유 무기 전부의 무게를 합산.
	var h := _human_weapons(0, ["sword", "bow"])
	assert_eq(CombatResolver.equip_weight(h), 5, "여러 무기 무게 전부 합산")

func test_evasion_reduced_by_weight() -> void:
	# 민첩 40 → 기본 20. 검(3)+사슬갑옷(8) 무게 11 → 20 − 11×0.3 = 20 − 3.3 = 16.7.
	var h := _human(0, 40, 0, 40, "sword", ["chain_mail"])
	assert_almost_eq(CombatResolver.evasion(h), 16.7, 0.001, "무게가 회피를 깎는다")

func test_heavier_gear_lower_evasion() -> void:
	var light := _human(0, 60, 0, 40, "wand", ["robe"])              # 무게 1+2=3
	var heavy := _human(0, 60, 0, 40, "mace", ["chain_mail"], "tower_shield")  # 무게 5+8+8=21
	assert_true(CombatResolver.evasion(heavy) < CombatResolver.evasion(light), "같은 민첩이면 무거울수록 회피 낮음")

func test_hit_chance_ninety_minus_evasion() -> void:
	var attacker := _human()
	var defender := _human(0, 40)   # 회피 20
	assert_eq(CombatResolver.hit_chance(attacker, defender), 70.0, "명중 = 90 − 20 = 70")

func test_crit_chance_half_luck() -> void:
	assert_eq(CombatResolver.crit_chance(_human(0, 0, 60)), 30.0, "행운 60 → 치명 30")

func test_hit_damage_min_one_and_crit_multiplier() -> void:
	var bare := _human()   # 맨몸 방어자(DF 0, 상성 1.0)
	assert_eq(CombatResolver.hit_damage(_human(78), bare, false), 15, "AT 15 vs 맨몸 평타 → 15")
	assert_eq(CombatResolver.hit_damage(_human(78), bare, true), 22, "AT 15 치명 → floor(15×1.5)=22")
	assert_eq(CombatResolver.hit_damage(_human(4), bare, false), 1, "AT 0이어도 최소 1")

func test_hit_damage_subtracts_defense() -> void:
	var atk := _human(78, 0, 0, 40, "sword")   # AT = 14 + 15 = 29
	var def := _human(0, 0, 0, 40, "", ["leather_armor"])   # DF 8, 가죽. 참격 vs 가죽 = 0.9
	# floor(max(1, 29-8) * 0.9) = floor(21*0.9) = floor(18.9) = 18
	assert_eq(CombatResolver.hit_damage(atk, def, false), 18, "AT29 − DF8 = 21, ×참격/가죽 0.9 = 18")

func test_hit_damage_affinity() -> void:
	# 마법(완드 8, AT=8) vs 판금(1.3) > vs 맨몸(1.0).
	var mage := _human(0, 0, 0, 40, "wand")   # AT = 8 + 0 = 8
	var plate := _human(0, 0, 0, 40, "", ["chain_mail"])   # 사슬 갑옷: 마법 vs 사슬 = 1.1
	var bare := _human()
	var d_plate := CombatResolver.hit_damage(mage, plate, false)   # floor(max(1,8-14)*1.1)=floor(1*1.1)=1
	var d_bare := CombatResolver.hit_damage(mage, bare, false)     # floor(max(1,8-0)*1.0)=8
	assert_eq(d_bare, 8, "마법 AT8 vs 맨몸 = 8")
	assert_true(d_plate >= 1, "방어력 높으면 최소 1 보장")

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

func test_shield_blocks_some_hits() -> void:
	# 항상 명중(회피 음수)하는 방어자에 타워 실드(막기 40%)를 들리고 여러 시드를 돌린다.
	var atk := _human(78, 0, 0, 40, "sword")            # 항상 명중용(방어자 회피 음수)
	var blocked := false
	var struck := false
	for s in range(1, 40):
		var def := _human(0, -100, 0, 40, "", [], "tower_shield")   # 항상 명중, 막기 40%
		var r := CombatResolver.resolve_hit(atk, def, 40, _rng(s))
		assert_true(r["hit"], "회피 음수 → 항상 명중")
		if r["blocked"]:
			blocked = true
			assert_eq(r["damage"], 0, "막으면 피해 0")
			assert_eq(r["hp"], 40, "막으면 hp 불변")
		else:
			struck = true
			assert_true(r["damage"] > 0, "막지 못하면 피해 발생")
	assert_true(blocked, "여러 시드 중 막힌 타격이 있다")
	assert_true(struck, "여러 시드 중 막지 못한 타격도 있다")

func test_no_shield_never_blocks() -> void:
	var atk := _human(78, 0, 0, 40, "sword")
	var def := _human(0, -100)   # 방패 없음, 항상 명중
	var r := CombatResolver.resolve_hit(atk, def, 40, _rng())
	assert_false(r["blocked"], "방패 없으면 막기 없음")

# --- 공격 간격 (attack_interval, 시간 기반 전투) ---

func test_attack_interval_base_at_zero_agility() -> void:
	# 민첩 0 → 무기 기본 공격속도 그대로. 검 2.0초.
	assert_almost_eq(CombatResolver.attack_interval(_human(0, 0, 0, 40, "sword")), 2.0, 0.001, "민첩 0이면 기본 공격속도")

func test_attack_interval_reduced_by_agility() -> void:
	# 민첩 60 → 검 2.0 × (1 − 60×0.005) = 2.0 × 0.7 = 1.4초.
	assert_almost_eq(CombatResolver.attack_interval(_human(0, 60, 0, 40, "sword")), 1.4, 0.001, "민첩이 공격 간격을 줄인다")

func test_attack_interval_floor() -> void:
	# 극단적으로 빠른 민첩이라도 하한(0.4초) 아래로 못 감.
	assert_almost_eq(CombatResolver.attack_interval(_human(0, 500, 0, 40, "sword")), 0.4, 0.001, "공격 간격 하한 0.4초")

func test_attack_interval_explicit_weapon() -> void:
	# 무기 명시 — 검+활 소지자에 활(기본 3.3) 지정, 민첩 0 → 3.3초.
	var h := _human_weapons(0, ["sword", "bow"])
	assert_almost_eq(CombatResolver.attack_interval(h, "bow"), 3.3, 0.001, "명시 무기(활)의 공격속도 사용")

func test_attack_interval_uses_primary_by_default() -> void:
	# 생략 시 주무기(곡도 1.8) 기준.
	var h := _human_weapons(0, ["scimitar", "javelin"])
	assert_almost_eq(CombatResolver.attack_interval(h), 1.8, 0.001, "생략 시 주무기 공격속도")
