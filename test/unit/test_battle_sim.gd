extends GutTest
## 헤드리스 전투 결산(BattleSim) 테스트 — 순수 함수. NPC끼리 전투를 화면 없이 결산.
## 확률은 극단 능력치로 강제한다: 회피 200↑ → 항상 빗나감 / 회피 음수 → 항상 명중.

# 투석 볼리(5g-B) 명중 시드 — CATAPULT_HIT_CHANCE 0.1이라 특정 시드로 명중을 강제한다(멤버 없는 투석기 대 투석기 기준).
const SEED_A_HITS := 13     # 첫 발(A→B 투석기) 명중
const SEED_BOTH_HIT := 105  # A→B 명중 + B→A 명중(상호 반격)

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
	var r := BattleSim.resolve_battle(a, b, _rng(), 2)
	assert_eq(r["b"].size(), 0, "근접만 든 B는 반격 못 하고 전멸")
	assert_eq(r["a"].size(), 1, "원거리 A는 무사")

func test_ranged_mode_secondary_bow_can_retaliate() -> void:
	# 원거리 모드: A는 활만, B는 검+활(보조). B는 활로 반격 가능 → 양측 사격.
	# A가 항상 명중·즉사시키지만, B도 활을 들어 '행동 가능'하다(공격 못 하는 검전용과 대비).
	var a := [_human(1000, -100, 0, 40, "bow")]
	var b := [_human_weapons(1000, -100, 0, 40, ["sword", "bow"])]
	var r := BattleSim.resolve_battle(a, b, _rng(), 2)
	# 둘 다 활을 들어 서로 사격 — 선(先)순회한 A가 먼저 B를 처치(항상 명중·즉사).
	assert_eq(r["b"].size(), 0, "검+활 B도 사격 대상이 되고, 먼저 맞아 전멸")
	assert_eq(r["a"].size(), 1, "A 생존")

func test_ranged_mode_melee_only_cannot_retaliate() -> void:
	# 대조군: B가 검만 들면 원거리 모드에서 공격(반격) 자체를 못 한다(활 없음).
	var a := [_human(1, 200, 0, 40, "bow")]        # 회피 높은 상대라 A는 못 맞힘(무피해)
	var b := [_human(1, 200, 0, 40, "sword")]      # 검만 → 원거리 모드 공격 불가
	var r := BattleSim.resolve_battle(a, b, _rng(), 2)
	assert_eq(r["a"].size(), 1, "A 생존")
	assert_eq(r["b"].size(), 1, "B 생존 — 검만이라 애초에 공격 못 함")

func test_ranged_mode_both_melee_no_damage() -> void:
	# 원거리 모드 + 양팀 근접만 → 아무도 공격 못 해 전원 생존.
	var a := [_human(1000, -100, 0, 40, "sword")]
	var b := [_human(1000, -100, 0, 40, "sword")]
	var r := BattleSim.resolve_battle(a, b, _rng(), 2)
	assert_eq(r["a"].size(), 1, "근접만이라 A 공격 못 함 → 생존")
	assert_eq(r["b"].size(), 1, "근접만이라 B 공격 못 함 → 생존")

# --- 거리 게이트(distance) — 사거리 ≥ distance인 유닛만 사격 ---

func test_distance_gate_wand_idle_at_3_active_at_2() -> void:
	# 완드(사거리 2) 강자+항상명중, B는 검(근접)·회피 낮음.
	# 거리 3: 완드(2) < 3 → 공격 못 함 → 아무도 안 죽음. 거리 2: 완드 사격 → B 즉사.
	var a3 := [_human(1000, -100, 0, 40, "wand")]
	var b3 := [_human(1, -100, 0, 40, "sword")]
	var r3 := BattleSim.resolve_battle(a3, b3, _rng(), 3)
	assert_eq(r3["b"].size(), 1, "거리 3에선 완드(2) 사거리 부족 → B 생존")
	var a2 := [_human(1000, -100, 0, 40, "wand")]
	var b2 := [_human(1, -100, 0, 40, "sword")]
	var r2 := BattleSim.resolve_battle(a2, b2, _rng(), 2)
	assert_eq(r2["b"].size(), 0, "거리 2에선 완드 사격 → B 전멸")

func test_distance_gate_bow_active_at_3() -> void:
	# 활(사거리 3)은 거리 3에서 사격 가능 → B 전멸.
	var a := [_human(1000, -100, 0, 40, "bow")]
	var b := [_human(1, -100, 0, 40, "sword")]
	var r := BattleSim.resolve_battle(a, b, _rng(), 3)
	assert_eq(r["b"].size(), 0, "활(3)은 거리 3 사격 → B 전멸")
	assert_eq(r["a"].size(), 1, "A 생존")

func test_distance_1_melee_all_attack() -> void:
	# 근접(거리 1, 기본): 검(근접)도 공격. 거리 2에선 같은 검이 사거리 부족으로 대기.
	var a1 := [_human(1000, -100, 0, 40, "sword")]
	var b1 := [_human(1, -100, 0, 40, "sword")]
	var r1 := BattleSim.resolve_battle(a1, b1, _rng(), 1)
	assert_eq(r1["b"].size(), 0, "거리 1(근접) — 검 공격 → B 전멸")
	var a2 := [_human(1000, -100, 0, 40, "sword")]
	var b2 := [_human(1, -100, 0, 40, "sword")]
	var r2 := BattleSim.resolve_battle(a2, b2, _rng(), 2)
	assert_eq(r2["b"].size(), 1, "거리 2 — 검(근접)은 사거리 부족으로 대기 → B 생존")

# --- 상태이상(출혈·기절) 연동 ---
# docs/spec/features/status-effects.md 참조. 극단 능력치로 명중·치명을 강제해 결정적으로 검증.

func _full(strength := 0, agility := 0, luck := 0, hp := 40, weapon := "", armor := []) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new()
	h.strength = strength
	h.agility = agility
	h.luck = luck
	h.hit_points = hp
	h.weapons = ([] if weapon == "" else [weapon])
	h.armor = armor
	return h

func test_bleed_speeds_up_wipe() -> void:
	# 방어자 B: 사슬갑옷(DF8), hp40, 회피 음수(A가 항상 명중).
	# A: 검(참격), 힘0(AT14), 민첩0(간격2.0 → 10초에 5타), hp 거대(반격에 안 죽음).
	#   참격 vs 사슬 0.7 → 치명 직격 = floor(6×0.7×1.5)=6. 5타 = 30 < 40 (직격만으론 못 죽임).
	#   ⇒ B가 죽으면 그 초과분은 출혈 도트의 기여다.
	# 대조군: A 행운 0 → 치명·출혈 없음, 직격 = floor(6×0.7)=4, 5타=20 < 40 → B 생존.
	var a_bleed := [_full(0, 0, 200, 100000, "sword")]   # 항상 치명 → 출혈
	var b1 := [_full(0, -100, 0, 40, "sword", ["chain_mail"])]
	var r_bleed := BattleSim.resolve_battle(a_bleed, b1, _rng())
	assert_eq(r_bleed["b"].size(), 0, "출혈 도트가 더해져 B 전멸")

	var a_plain := [_full(0, 0, 0, 100000, "sword")]      # 치명 없음 → 출혈 없음
	var b2 := [_full(0, -100, 0, 40, "sword", ["chain_mail"])]
	var r_plain := BattleSim.resolve_battle(a_plain, b2, _rng())
	assert_eq(r_plain["b"].size(), 1, "직격만으론(치명·출혈 없음) B 생존")

func test_stun_prevents_attacks() -> void:
	# A: 모닝스타(타격), 힘0, 민첩-100(간격 2.8×1.5=4.2 → 4.2·8.4 공격), 행운200(항상 치명→기절),
	#    회피 -50(B가 항상 명중), hp50.
	# B: 검, 힘100(AT34), 민첩-100(간격 3.0 → 3·6·9), 회피 -50(A가 항상 명중), hp 거대.
	#   기절이 있으면: B는 t=3.0에 1회만 공격(A hp50→16), 이후 t=6·9는 기절로 스킵 → A 생존.
	#   기절이 없으면(대조군, A가 자돌 창): B가 t=3·6에 공격 → A(50) 2타(68)로 사망.
	var a_stun := [_full(0, -100, 200, 50, "mace")]
	var b1 := [_full(100, -100, 0, 100000, "sword")]
	var r_stun := BattleSim.resolve_battle(a_stun, b1, _rng())
	assert_eq(r_stun["a"].size(), 1, "기절한 B가 이후 공격을 못 해 A 생존")

	var a_ctrl := [_full(0, -100, 200, 50, "spear")]   # 자돌 치명 → 상태이상 없음(대조)
	var b2 := [_full(100, -100, 0, 100000, "sword")]
	var r_ctrl := BattleSim.resolve_battle(a_ctrl, b2, _rng())
	assert_eq(r_ctrl["a"].size(), 0, "기절 없으면 B가 반복 공격해 A 처치")

func test_deterministic_same_seed() -> void:
	# resolve_battle이 생존자 hit_points를 덮어쓰므로(부작용) 입력을 매번 새로 만든다.
	var r1 := BattleSim.resolve_battle([_human(60, 20), _human(55, 25)], [_human(58, 22), _human(52, 28)], _rng(7))
	var r2 := BattleSim.resolve_battle([_human(60, 20), _human(55, 25)], [_human(58, 22), _human(52, 28)], _rng(7))
	assert_eq(r1["a"].size(), r2["a"].size(), "같은 시드 → 같은 A 생존 수")
	assert_eq(r1["b"].size(), r2["b"].size(), "같은 시드 → 같은 B 생존 수")

# --- 전투 후 생명점 지속 (battle.md) ---
func _full_hp(strength := 0, agility := 0, luck := 0, hp := 40, weapon := "", armor := []) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new()
	h.strength = strength
	h.agility = agility
	h.luck = luck
	h.hit_points = hp
	h.weapons = ([] if weapon == "" else [weapon])
	h.armor = armor
	return h

func test_survivor_hp_persists() -> void:
	# A: 검(참격), 힘0(AT14), 민첩0(간격2.0 → 10초에 5타), 행운0(치명 없음), hp 거대(반격에 안 죽음).
	# B: 가죽갑옷(DF8), hp40, 회피 음수(A가 항상 명중). 참격 vs 가죽 0.9 → 타당 = floor(6×0.9)=5. 5타 = 25.
	var a := [_full_hp(0, 0, 0, 100000, "sword")]
	var b := _full_hp(0, -100, 0, 40, "sword", ["leather_armor"])
	var r := BattleSim.resolve_battle(a, [b], _rng())
	assert_eq(r["b"].size(), 1, "B 생존")
	assert_eq(b.hit_points, 15, "생존자 hp가 전투 후 감소해 지속(40 − 5×5 = 15)")
	assert_true(b.hit_points >= 1 and b.hit_points <= b.max_hp(), "1 ≤ hp ≤ max_hp()")

func test_unharmed_survivor_hp_unchanged() -> void:
	# 양측 회피 200 → 아무도 못 맞힘 → 피해 0 → 생존자 hp 불변.
	var a := [_full_hp(60, 200, 0, 40, "sword")]
	var b := _full_hp(60, 200, 0, 40, "sword")
	var r := BattleSim.resolve_battle(a, [b], _rng())
	assert_eq(r["b"].size(), 1, "B 생존")
	assert_eq(b.hit_points, 40, "피해를 안 받은 생존자는 hp 불변")

# --- NPC↔NPC 투석기 결투 (5g-B, 투석 볼리 프리페이즈) → docs/spec/features/battle.md ---

func _catapult() -> Object:
	return load("res://scenes/siege/siege_unit.gd").new()   # 투석기: 사거리 4~5·공격 50·hp 60

func test_bombard_pick_siege_first() -> void:
	# 적 투석기 우선 → 멤버, 최대 n. 타입 무관 순서·슬라이스만.
	assert_eq(BattleSim.bombard_pick([1, 2], [3, 4, 5], 5), [1, 2, 3, 4, 5], "투석기 먼저 그다음 멤버")
	assert_eq(BattleSim.bombard_pick([1, 2, 3], [4, 5], 4), [1, 2, 3, 4], "최대 n(4)까지")
	assert_eq(BattleSim.bombard_pick([], [], 5), [], "적 없으면 빈 배열")

func test_siege_no_fire_below_band() -> void:
	# 거리 1(밴드 4~5 밖) → 투석기 미발사. 양측 투석기 hp 불변.
	var sa := _catapult()
	var sb := _catapult()
	BattleSim.resolve_battle([], [], _rng(), 1, [sa], [sb])
	assert_eq(sa.hit_points, 60, "밴드 밖 → A 투석기 미발사(hp 60)")
	assert_eq(sb.hit_points, 60, "밴드 밖 → B 투석기 미발사(hp 60)")

func test_siege_hits_in_band() -> void:
	# 거리 4(밴드 안) + 명중 시드 → A 투석기가 B 투석기(유일 표적)에 피해. 멤버 없이 투석기 대 투석기.
	var sa := _catapult()
	var sb := _catapult()
	BattleSim.resolve_battle([], [], _rng(SEED_A_HITS), 4, [sa], [sb])
	assert_lt(sb.hit_points, 60, "명중 시 B 투석기 hp 감소")

func test_siege_mutual_counter() -> void:
	# 거리 4 + 양측 명중 시드 → 상호 반격(둘 다 hp 감소, 한쪽만 깎이지 않음).
	var sa := _catapult()
	var sb := _catapult()
	BattleSim.resolve_battle([], [], _rng(SEED_BOTH_HIT), 4, [sa], [sb])
	assert_lt(sa.hit_points, 60, "A 투석기도 반격당해 hp 감소")
	assert_lt(sb.hit_points, 60, "B 투석기 hp 감소")

func test_no_siege_regression() -> void:
	# siege 인자 생략 == 빈 배열 → 멤버 전투 결과 동일(볼리 스킵).
	var r_none := BattleSim.resolve_battle([_human(60, 20)], [_human(58, 22)], _rng(7))
	var r_empty := BattleSim.resolve_battle([_human(60, 20)], [_human(58, 22)], _rng(7), 1, [], [])
	assert_eq(r_none["a"].size(), r_empty["a"].size(), "siege 없음 = 빈 siege, A 생존 동일")
	assert_eq(r_none["b"].size(), r_empty["b"].size(), "siege 없음 = 빈 siege, B 생존 동일")
